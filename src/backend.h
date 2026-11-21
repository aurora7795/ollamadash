#pragma once

#include <QDateTime>
#include <QNetworkAccessManager>
#include <QObject>
#include <QTimer>
#include <QUrl>
#include <QVariantList>

// Polls a local Ollama server and the machine's own CPU and memory, and hands
// the results to QML as plain properties.
class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QString error READ error NOTIFY connectedChanged)
    Q_PROPERTY(QString host READ host NOTIFY hostChanged)
    // The CPU and memory graphs read this machine's /proc, so they only mean
    // something when Ollama runs here too.
    Q_PROPERTY(bool local READ local NOTIFY hostChanged)
    // False until the current host has answered, or failed to, at least once.
    Q_PROPERTY(bool checked READ checked NOTIFY connectedChanged)
    Q_PROPERTY(QString version READ version NOTIFY modelsChanged)
    Q_PROPERTY(QVariantList running READ running NOTIFY modelsChanged)
    Q_PROPERTY(QVariantList installed READ installed NOTIFY modelsChanged)
    // What /api/show says about the model last asked for, for the detail dialog.
    Q_PROPERTY(QVariantMap detail READ detail NOTIFY detailChanged)
    Q_PROPERTY(bool detailLoading READ detailLoading NOTIFY detailChanged)
    Q_PROPERTY(QString detailError READ detailError NOTIFY detailChanged)
    Q_PROPERTY(double cpu READ cpu NOTIFY systemChanged)
    Q_PROPERTY(qlonglong memoryUsed READ memoryUsed NOTIFY systemChanged)
    Q_PROPERTY(qlonglong memoryTotal READ memoryTotal NOTIFY systemChanged)
    Q_PROPERTY(QVariantList cpuHistory READ cpuHistory NOTIFY systemChanged)
    Q_PROPERTY(QVariantList memoryHistory READ memoryHistory NOTIFY systemChanged)

public:
    struct CpuTimes {
        quint64 total = 0;
        quint64 idle = 0;
    };
    struct Memory {
        qint64 total = 0;
        qint64 available = 0;
    };

    // The host comes from the argument, else the saved setting, else $OLLAMA_HOST,
    // else 127.0.0.1:11434.
    explicit Backend(const QString &host = {}, QObject *parent = nullptr);

    bool connected() const { return m_connected; }
    bool checked() const { return m_checked; }
    QString error() const { return m_error; }
    QString host() const { return m_host; }
    bool local() const { return m_local; }
    QString version() const { return m_version; }
    QVariantList running() const { return m_running; }
    QVariantList installed() const { return m_installed; }
    QVariantMap detail() const { return m_detail; }
    bool detailLoading() const { return m_detailLoading; }
    QString detailError() const { return m_detailError; }
    double cpu() const { return m_cpu; }
    qlonglong memoryUsed() const { return m_memoryTotal - m_memoryAvailable; }
    qlonglong memoryTotal() const { return m_memoryTotal; }
    QVariantList cpuHistory() const { return m_cpuHistory; }
    QVariantList memoryHistory() const { return m_memoryHistory; }

    void start();
    Q_INVOKABLE void refresh();
    // Saves the host and switches to it. An empty string clears the saved choice
    // and goes back to $OLLAMA_HOST or the default. False if it is not an address.
    Q_INVOKABLE bool setHost(const QString &host);
    // Fetches /api/show for one model; the result lands in `detail`.
    Q_INVOKABLE void showModel(const QString &name);
    // Asks Ollama to drop a model from memory right away (keep_alive of 0).
    Q_INVOKABLE void unload(const QString &model);
    Q_INVOKABLE QString formatBytes(qlonglong bytes) const;

    // Pure parsing, kept static so tests can feed it canned responses.
    static QUrl hostUrl(QString value);
    static QVariantList parseRunning(const QByteArray &json, const QDateTime &now);
    static QVariantMap parseShow(const QByteArray &json);
    static QVariantList parseInstalled(const QByteArray &json);
    static CpuTimes parseCpuTimes(const QByteArray &procStat);
    static Memory parseMemory(const QByteArray &procMeminfo);

signals:
    void hostChanged();
    void connectedChanged();
    void modelsChanged();
    void detailChanged();
    void systemChanged();

private:
    void poll();
    void sampleSystem();
    void fetchRunning();
    void fetchInstalled();
    void applyHost(const QUrl &url);
    void setConnected(bool connected, const QString &error);
    QNetworkReply *get(const QString &path);

    QUrl m_url;
    QString m_host;
    bool m_local = true;
    QNetworkAccessManager m_network;
    QTimer m_timer;
    int m_tick = 0;
    bool m_runningPending = false;

    // Bumped on every host change so replies from the old host are dropped.
    int m_generation = 0;
    bool m_checked = false;
    bool m_connected = false;
    QString m_error;
    QString m_version;
    QVariantList m_running, m_installed;
    QVariantMap m_detail;
    bool m_detailLoading = false;
    QString m_detailError;
    // Bumped per request, so a slow answer for an earlier click is dropped.
    int m_detailRequest = 0;

    CpuTimes m_lastCpu;
    double m_cpu = 0;
    qint64 m_memoryTotal = 0, m_memoryAvailable = 0;
    QVariantList m_cpuHistory, m_memoryHistory;
};
