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
    Q_PROPERTY(QString host READ host CONSTANT)
    // The CPU and memory graphs read this machine's /proc, so they only mean
    // something when Ollama runs here too.
    Q_PROPERTY(bool local READ local CONSTANT)
    Q_PROPERTY(QString version READ version NOTIFY modelsChanged)
    Q_PROPERTY(QVariantList running READ running NOTIFY modelsChanged)
    Q_PROPERTY(QVariantList installed READ installed NOTIFY modelsChanged)
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

    // An empty host falls back to $OLLAMA_HOST, then to 127.0.0.1:11434.
    explicit Backend(const QString &host = {}, QObject *parent = nullptr);

    bool connected() const { return m_connected; }
    QString error() const { return m_error; }
    QString host() const { return m_host; }
    bool local() const { return m_local; }
    QString version() const { return m_version; }
    QVariantList running() const { return m_running; }
    QVariantList installed() const { return m_installed; }
    double cpu() const { return m_cpu; }
    qlonglong memoryUsed() const { return m_memoryTotal - m_memoryAvailable; }
    qlonglong memoryTotal() const { return m_memoryTotal; }
    QVariantList cpuHistory() const { return m_cpuHistory; }
    QVariantList memoryHistory() const { return m_memoryHistory; }

    void start();
    Q_INVOKABLE void refresh();
    // Asks Ollama to drop a model from memory right away (keep_alive of 0).
    Q_INVOKABLE void unload(const QString &model);
    Q_INVOKABLE QString formatBytes(qlonglong bytes) const;

    // Pure parsing, kept static so tests can feed it canned responses.
    static QUrl hostUrl(QString value);
    static QVariantList parseRunning(const QByteArray &json, const QDateTime &now);
    static QVariantList parseInstalled(const QByteArray &json);
    static CpuTimes parseCpuTimes(const QByteArray &procStat);
    static Memory parseMemory(const QByteArray &procMeminfo);

signals:
    void connectedChanged();
    void modelsChanged();
    void systemChanged();

private:
    void poll();
    void sampleSystem();
    void fetchRunning();
    void fetchInstalled();
    void setConnected(bool connected, const QString &error);
    QNetworkReply *get(const QString &path);

    QUrl m_url;
    QString m_host;
    bool m_local = true;
    QNetworkAccessManager m_network;
    QTimer m_timer;
    int m_tick = 0;
    bool m_runningPending = false;

    bool m_connected = false;
    QString m_error;
    QString m_version;
    QVariantList m_running, m_installed;

    CpuTimes m_lastCpu;
    double m_cpu = 0;
    qint64 m_memoryTotal = 0, m_memoryAvailable = 0;
    QVariantList m_cpuHistory, m_memoryHistory;
};
