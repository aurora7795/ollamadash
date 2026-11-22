#include "backend.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSettings>
#include <QRegularExpression>
#include <algorithm>

namespace {

// Two minutes of history at the two second poll interval.
constexpr int HistoryLength = 60;
constexpr int PollMilliseconds = 2000;
// The installed list and version change rarely, so ask for them every fifth poll.
constexpr int SlowPollEvery = 5;

QByteArray readFile(const QString &path) {
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
}

void push(QVariantList &list, double value) {
    list.append(value);
    while (list.size() > HistoryLength)
        list.removeFirst();
}

// Go prints nanoseconds, which Qt's ISO parser doesn't accept past milliseconds.
QDateTime parseTime(QString text) {
    static const QRegularExpression fraction(R"(\.(\d{3})\d+)");
    text.replace(fraction, ".\\1");
    QDateTime time = QDateTime::fromString(text, Qt::ISODateWithMs);
    return time.isValid() ? time : QDateTime::fromString(text, Qt::ISODate);
}

} // namespace

static QSettings settings() { return QSettings("ollamadash", "ollamadash"); }

namespace {

struct SavedHost {
    QString name;
    QString address;
};

QList<SavedHost> loadHosts() {
    QSettings s("ollamadash", "ollamadash");
    QList<SavedHost> hosts;
    const int count = s.beginReadArray("hosts");
    for (int i = 0; i < count; ++i) {
        s.setArrayIndex(i);
        hosts.append({s.value("name").toString(), s.value("address").toString()});
    }
    s.endArray();
    return hosts;
}

void saveHosts(const QList<SavedHost> &hosts) {
    QSettings s("ollamadash", "ollamadash");
    s.remove("hosts");
    s.beginWriteArray("hosts", hosts.size());
    for (int i = 0; i < hosts.size(); ++i) {
        s.setArrayIndex(i);
        s.setValue("name", hosts[i].name);
        s.setValue("address", hosts[i].address);
    }
    s.endArray();
}

// Two spellings of one server (a bare name and one with the default port) are the same host.
int indexOfAddress(const QList<SavedHost> &hosts, const QUrl &url) {
    for (int i = 0; i < hosts.size(); ++i)
        if (Backend::hostUrl(hosts[i].address) == url)
            return i;
    return -1;
}

} // namespace

Backend::Backend(const QString &host, QObject *parent) : QObject(parent) {
    QString chosen = host;
    if (chosen.isEmpty()) {
        chosen = settings().value("host").toString();
        // Before there was a list, the one chosen host was all that was saved; keep it as the first entry.
        const QUrl saved = hostUrl(chosen);
        QList<SavedHost> hosts = loadHosts();
        if (saved.isValid() && !chosen.isEmpty() && indexOfAddress(hosts, saved) < 0) {
            hosts.append({QString(), chosen});
            saveHosts(hosts);
        }
    }
    if (chosen.isEmpty())
        chosen = qEnvironmentVariable("OLLAMA_HOST");
    QUrl url = hostUrl(chosen);
    // A hand-edited or stale setting shouldn't leave the app without a server.
    applyHost(url.isValid() ? url : hostUrl({}));
    m_timer.setInterval(PollMilliseconds);
    connect(&m_timer, &QTimer::timeout, this, &Backend::poll);
}

void Backend::start() {
    // One sample now so the first timer tick has a baseline to diff the CPU against.
    sampleSystem();
    refresh();
    m_timer.start();
}

void Backend::applyHost(const QUrl &url) {
    m_url = url;
    m_host = url.host() + (url.port() > 0 ? ":" + QString::number(url.port()) : QString());
    m_local = url.host() == "127.0.0.1" || url.host() == "localhost" || url.host() == "::1";
    ++m_generation;
    m_runningPending = false;
    m_checked = false;
    m_connected = false;
    m_error.clear();
    m_version.clear();
    m_running.clear();
    m_installed.clear();
}

void Backend::switchTo(const QUrl &url) {
    applyHost(url);
    emit hostChanged();
    emit hostsChanged();
    emit connectedChanged();
    emit modelsChanged();
    refresh();
}

QString Backend::hostLabel() const {
    const QList<SavedHost> saved = loadHosts();
    const int index = indexOfAddress(saved, m_url);
    return index >= 0 && !saved[index].name.isEmpty() ? saved[index].name : m_host;
}

QVariantList Backend::hosts() const {
    const QList<SavedHost> saved = loadHosts();
    const int current = indexOfAddress(saved, m_url);
    QVariantList out;
    for (int i = 0; i < saved.size(); ++i)
        out.append(QVariantMap{{"name", saved[i].name},
                               {"address", saved[i].address},
                               {"label", saved[i].name.isEmpty() ? saved[i].address : saved[i].name},
                               {"current", i == current}});
    return out;
}

int Backend::hostIndex() const { return indexOfAddress(loadHosts(), m_url); }

bool Backend::addHost(const QString &name, const QString &address) {
    const QString chosen = address.trimmed();
    const QUrl url = hostUrl(chosen);
    if (chosen.isEmpty() || !url.isValid())
        return false;
    QList<SavedHost> saved = loadHosts();
    const int existing = indexOfAddress(saved, url);
    if (existing >= 0) {
        if (!name.trimmed().isEmpty())
            saved[existing].name = name.trimmed();
    } else {
        saved.append({name.trimmed(), chosen});
    }
    saveHosts(saved);
    settings().setValue("host", chosen);
    switchTo(url);
    return true;
}

void Backend::selectHost(int index) {
    const QList<SavedHost> saved = loadHosts();
    if (index < 0 || index >= saved.size())
        return;
    const QUrl url = hostUrl(saved[index].address);
    if (!url.isValid())
        return;
    settings().setValue("host", saved[index].address);
    // Choosing the host already on screen shouldn't blank it and start over.
    if (url == m_url)
        return;
    switchTo(url);
}

void Backend::removeHost(int index) {
    QList<SavedHost> saved = loadHosts();
    if (index < 0 || index >= saved.size())
        return;
    const bool wasCurrent = index == indexOfAddress(saved, m_url);
    saved.removeAt(index);
    saveHosts(saved);
    if (!wasCurrent) {
        emit hostChanged();
        emit hostsChanged();
        return;
    }
    if (saved.isEmpty())
        useDefaultHost();
    else
        selectHost(0);
}

void Backend::useDefaultHost() {
    settings().remove("host");
    const QUrl url = hostUrl(qEnvironmentVariable("OLLAMA_HOST"));
    switchTo(url.isValid() ? url : hostUrl({}));
}

void Backend::refresh() {
    m_tick = 0;
    poll();
}

void Backend::poll() {
    sampleSystem();
    fetchRunning();
    if (m_tick++ % SlowPollEvery == 0)
        fetchInstalled();
}

QNetworkReply *Backend::get(const QString &path) {
    QUrl url = m_url;
    url.setPath(path);
    QNetworkRequest request(url);
    request.setTransferTimeout(3000);
    return m_network.get(request);
}

void Backend::fetchRunning() {
    if (m_runningPending)
        return;
    m_runningPending = true;
    const int generation = m_generation;
    QNetworkReply *reply = get("/api/ps");
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation] {
        reply->deleteLater();
        if (generation != m_generation)
            return;
        m_runningPending = false;
        if (reply->error() != QNetworkReply::NoError) {
            m_running.clear();
            m_installed.clear();
            setConnected(false, reply->errorString());
            emit modelsChanged();
            return;
        }
        setConnected(true, {});
        m_running = parseRunning(reply->readAll(), QDateTime::currentDateTime());
        emit modelsChanged();
    });
}

void Backend::fetchInstalled() {
    const int generation = m_generation;
    QNetworkReply *tags = get("/api/tags");
    connect(tags, &QNetworkReply::finished, this, [this, tags, generation] {
        tags->deleteLater();
        if (generation != m_generation)
            return;
        // A failure here is reported by the /api/ps request, which runs every poll.
        if (tags->error() != QNetworkReply::NoError)
            return;
        m_installed = parseInstalled(tags->readAll());
        emit modelsChanged();
    });
    QNetworkReply *version = get("/api/version");
    connect(version, &QNetworkReply::finished, this, [this, version, generation] {
        version->deleteLater();
        if (generation != m_generation)
            return;
        if (version->error() != QNetworkReply::NoError)
            return;
        m_version = QJsonDocument::fromJson(version->readAll()).object().value("version").toString();
        emit modelsChanged();
    });
}

void Backend::showModel(const QString &name) {
    const int request = ++m_detailRequest;
    const int generation = m_generation;
    m_detail = QVariantMap{{"name", name}};
    m_detailLoading = true;
    m_detailError.clear();
    emit detailChanged();

    QUrl url = m_url;
    url.setPath("/api/show");
    QNetworkRequest httpRequest(url);
    httpRequest.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    httpRequest.setTransferTimeout(5000);
    const QJsonObject body{{"model", name}};
    QNetworkReply *reply = m_network.post(httpRequest, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply, request, generation, name] {
        reply->deleteLater();
        if (request != m_detailRequest || generation != m_generation)
            return;
        m_detailLoading = false;
        if (reply->error() != QNetworkReply::NoError) {
            m_detailError = reply->errorString();
            emit detailChanged();
            return;
        }
        QVariantMap detail = parseShow(reply->readAll());
        detail["name"] = name;
        // Size and digest live in the tags list, not in /api/show.
        for (const QVariant &entry : std::as_const(m_installed)) {
            const QVariantMap model = entry.toMap();
            if (model.value("name").toString() == name) {
                detail["size"] = model.value("size");
                detail["digest"] = model.value("digest");
            }
        }
        m_detail = detail;
        emit detailChanged();
    });
}

void Backend::unload(const QString &model) {
    QUrl url = m_url;
    url.setPath("/api/generate");
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setTransferTimeout(5000);
    const QJsonObject body{{"model", model}, {"keep_alive", 0}};
    QNetworkReply *reply = m_network.post(request, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        fetchRunning();
    });
}

void Backend::setConnected(bool connected, const QString &error) {
    if (m_checked && connected == m_connected && error == m_error)
        return;
    m_checked = true;
    m_connected = connected;
    m_error = error;
    emit connectedChanged();
}

void Backend::sampleSystem() {
    const CpuTimes now = parseCpuTimes(readFile("/proc/stat"));
    if (m_lastCpu.total > 0 && now.total > m_lastCpu.total) {
        const double total = now.total - m_lastCpu.total;
        const double idle = now.idle - m_lastCpu.idle;
        m_cpu = qBound(0.0, 100.0 * (1.0 - idle / total), 100.0);
        push(m_cpuHistory, m_cpu);
    }
    m_lastCpu = now;

    const Memory memory = parseMemory(readFile("/proc/meminfo"));
    m_memoryTotal = memory.total;
    m_memoryAvailable = memory.available;
    if (memory.total > 0)
        push(m_memoryHistory, 100.0 * (memory.total - memory.available) / memory.total);
    emit systemChanged();
}

QString Backend::formatBytes(qlonglong bytes) const {
    // Ollama reports model sizes in decimal gigabytes, so match it.
    return QLocale().formattedDataSize(bytes, 1, QLocale::DataSizeSIFormat);
}

QUrl Backend::hostUrl(QString value) {
    value = value.trimmed();
    if (value.isEmpty())
        value = "127.0.0.1:11434";
    const bool hasScheme = value.contains("://");
    if (!hasScheme)
        value.prepend("http://");

    // Strict parsing, so a typo like a stray space is rejected rather than repaired.
    QUrl url(value, QUrl::StrictMode);
    if (!url.isValid())
        return url;
    // A server bound to every interface is still reachable on loopback.
    if (url.host().isEmpty() || url.host() == "0.0.0.0" || url.host() == "::")
        url.setHost("127.0.0.1");
    if (url.port() < 0 && !hasScheme)
        url.setPort(11434);
    url.setPath({});
    return url;
}

QVariantList Backend::parseRunning(const QByteArray &json, const QDateTime &now) {
    QVariantList out;
    const QJsonArray models = QJsonDocument::fromJson(json).object().value("models").toArray();
    for (const QJsonValue &value : models) {
        const QJsonObject model = value.toObject();
        const QJsonObject details = model.value("details").toObject();
        const double size = model.value("size").toDouble();
        const double vram = model.value("size_vram").toDouble();

        qint64 expiresIn = -1;
        const QDateTime expires = parseTime(model.value("expires_at").toString());
        if (expires.isValid()) {
            const qint64 left = now.secsTo(expires);
            // Models kept loaded forever carry an expiry centuries away.
            expiresIn = left > 10LL * 365 * 24 * 3600 ? -1 : std::max<qint64>(0, left);
        }

        out.append(QVariantMap{
            {"name", model.value("name").toString()},
            {"size", size},
            {"sizeVram", vram},
            {"vramPercent", size > 0 ? qRound(100.0 * vram / size) : 0},
            {"contextLength", model.value("context_length").toInt()},
            {"expiresIn", expiresIn},
            {"parameterSize", details.value("parameter_size").toString()},
            {"quantization", details.value("quantization_level").toString()},
        });
    }
    return out;
}

QVariantMap Backend::parseShow(const QByteArray &json) {
    const QJsonObject root = QJsonDocument::fromJson(json).object();
    const QJsonObject details = root.value("details").toObject();
    const QJsonObject info = root.value("model_info").toObject();

    // Architecture-specific keys are prefixed by the architecture ("llama.context_length"),
    // so match on the suffix rather than guessing the prefix.
    auto number = [&info](const QString &suffix) {
        for (auto it = info.begin(); it != info.end(); ++it)
            if (!it.key().startsWith("general.") && it.key().endsWith(suffix))
                return it.value().toDouble();
        return 0.0;
    };

    // Licence files are long; the first line names the licence.
    QString license;
    for (const QString &line : root.value("license").toString().split('\n'))
        if (!line.trimmed().isEmpty()) {
            license = line.trimmed();
            break;
        }

    return QVariantMap{
        {"capabilities", root.value("capabilities").toArray().toVariantList()},
        {"architecture", info.value("general.architecture").toString()},
        {"parameterCount", info.value("general.parameter_count").toDouble()},
        {"contextLength", number(".context_length")},
        {"blockCount", number(".block_count")},
        {"embeddingLength", number(".embedding_length")},
        {"format", details.value("format").toString()},
        {"family", details.value("family").toString()},
        {"parameterSize", details.value("parameter_size").toString()},
        {"quantization", details.value("quantization_level").toString()},
        {"runner", details.value("runner").toString()},
        {"parameters", root.value("parameters").toString().trimmed()},
        {"template", root.value("template").toString().trimmed()},
        {"license", license},
        {"modified", parseTime(root.value("modified_at").toString())},
    };
}

QVariantList Backend::parseInstalled(const QByteArray &json) {
    QVariantList out;
    const QJsonArray models = QJsonDocument::fromJson(json).object().value("models").toArray();
    for (const QJsonValue &value : models) {
        const QJsonObject model = value.toObject();
        const QJsonObject details = model.value("details").toObject();
        out.append(QVariantMap{
            {"name", model.value("name").toString()},
            {"size", model.value("size").toDouble()},
            {"digest", model.value("digest").toString()},
            {"family", details.value("family").toString()},
            {"parameterSize", details.value("parameter_size").toString()},
            {"quantization", details.value("quantization_level").toString()},
            {"modified", parseTime(model.value("modified_at").toString())},
        });
    }
    // Newest first, the way people think of what they just pulled.
    std::sort(out.begin(), out.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value("modified").toDateTime() > b.toMap().value("modified").toDateTime();
    });
    return out;
}

Backend::CpuTimes Backend::parseCpuTimes(const QByteArray &procStat) {
    const QList<QByteArray> fields = procStat.left(procStat.indexOf('\n')).simplified().split(' ');
    if (fields.value(0) != "cpu" || fields.size() < 5)
        return {};
    // user nice system idle iowait irq softirq steal; guest time is already in user.
    quint64 total = 0;
    for (int i = 1; i < fields.size() && i <= 8; ++i)
        total += fields[i].toULongLong();
    return {total, fields[4].toULongLong() + fields.value(5).toULongLong()};
}

Backend::Memory Backend::parseMemory(const QByteArray &procMeminfo) {
    Memory memory;
    for (const QByteArray &line : procMeminfo.split('\n')) {
        const QList<QByteArray> parts = line.simplified().split(' ');
        if (parts.size() < 2)
            continue;
        if (parts[0] == "MemTotal:")
            memory.total = parts[1].toLongLong() * 1024;
        else if (parts[0] == "MemAvailable:")
            memory.available = parts[1].toLongLong() * 1024;
    }
    return memory;
}
