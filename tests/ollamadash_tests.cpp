#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QtTest>

#include "backend.h"
#include "theme.h"
#include "translator.h"

class OllamadashTests : public QObject {
    Q_OBJECT

private slots:
    void hostDefaultsToLoopback()
    {
        QCOMPARE(Backend::hostUrl("").toString(), QString("http://127.0.0.1:11434"));
        QCOMPARE(Backend::hostUrl("0.0.0.0:11434").toString(), QString("http://127.0.0.1:11434"));
        QCOMPARE(Backend::hostUrl(":11500").toString(), QString("http://127.0.0.1:11500"));
        QCOMPARE(Backend::hostUrl("gpu-box").toString(), QString("http://gpu-box:11434"));
        QCOMPARE(Backend::hostUrl("https://ollama.example.com").toString(), QString("https://ollama.example.com"));
    }

    void invalidHostsAreRejected()
    {
        QVERIFY(!Backend::hostUrl("bad host").isValid());
        QVERIFY(Backend::hostUrl("good-host:1234").isValid());
    }

    void parsesRunningModels()
    {
        const QByteArray json = R"({"models":[
            {"name":"llama3.2:3b","size":4000000000,"size_vram":3000000000,
             "expires_at":"2026-11-21T10:05:00.123456789+00:00","context_length":4096,
             "details":{"parameter_size":"3.2B","quantization_level":"Q4_K_M"}},
            {"name":"forever","size":100,"size_vram":0,
             "expires_at":"2318-01-01T00:00:00Z","details":{}}]})";
        const QDateTime now = QDateTime::fromString("2026-11-21T10:00:00Z", Qt::ISODate);

        const QVariantList models = Backend::parseRunning(json, now);
        QCOMPARE(models.size(), 2);

        const QVariantMap first = models[0].toMap();
        QCOMPARE(first["name"].toString(), QString("llama3.2:3b"));
        QCOMPARE(first["vramPercent"].toInt(), 75);
        QCOMPARE(first["expiresIn"].toLongLong(), 300LL);
        QCOMPARE(first["contextLength"].toInt(), 4096);
        QCOMPARE(first["quantization"].toString(), QString("Q4_K_M"));

        const QVariantMap second = models[1].toMap();
        QCOMPARE(second["expiresIn"].toLongLong(), -1LL);
        QCOMPARE(second["vramPercent"].toInt(), 0);
    }

    void expiredModelsDoNotGoNegative()
    {
        const QByteArray json = R"({"models":[{"name":"m","size":1,"size_vram":1,"expires_at":"2026-11-21T09:00:00Z"}]})";
        const QDateTime now = QDateTime::fromString("2026-11-21T10:00:00Z", Qt::ISODate);
        QCOMPARE(Backend::parseRunning(json, now)[0].toMap()["expiresIn"].toLongLong(), 0LL);
    }

    void installedModelsComeNewestFirst()
    {
        const QByteArray json = R"({"models":[
            {"name":"old","size":1,"modified_at":"2025-01-01T00:00:00Z"},
            {"name":"new","size":2,"modified_at":"2026-06-01T12:00:00.5Z"}]})";
        const QVariantList models = Backend::parseInstalled(json);
        QCOMPARE(models[0].toMap()["name"].toString(), QString("new"));
        QCOMPARE(models[1].toMap()["name"].toString(), QString("old"));
    }

    void garbageParsesToNothing()
    {
        QVERIFY(Backend::parseRunning("not json", QDateTime::currentDateTime()).isEmpty());
        QVERIFY(Backend::parseInstalled({}).isEmpty());
    }

    void parsesProcStat()
    {
        const auto times = Backend::parseCpuTimes("cpu  100 10 50 800 40 0 0 0 0 0\ncpu0 1 2 3 4\n");
        QCOMPARE(times.total, quint64(1000));
        QCOMPARE(times.idle, quint64(840));
        QCOMPARE(Backend::parseCpuTimes("nonsense").total, quint64(0));
    }

    void parsesMeminfo()
    {
        const auto memory = Backend::parseMemory("MemTotal:       16000 kB\nMemFree: 1 kB\nMemAvailable:    4000 kB\n");
        QCOMPARE(memory.total, qint64(16000) * 1024);
        QCOMPARE(memory.available, qint64(4000) * 1024);
    }

    void themeFallsBack()
    {
        QTemporaryDir dir;
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#FFD60A"));
        QCOMPARE(theme.accentForeground(), QString("black"));
    }

    void themeReadsAccent()
    {
        QTemporaryDir dir;
        QDir(dir.path()).mkpath("theme");
        write(dir.path() + "/theme/colors.toml", "accent = \"#112233\"\n");

        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#112233"));
        QCOMPARE(theme.accentForeground(), QString("white"));
    }

    void translatorFollowsTheLanguageFile()
    {
        QTemporaryDir dir;
        write(dir.path() + "/language", "pt-BR\n");
        write(dir.path() + "/pt.json", R"({"Quit": "Sair", "Open": "Abrir"})");
        write(dir.path() + "/pt-BR.json", R"({"Quit": "Fechar"})");

        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.language(), QString("pt-BR"));
        QCOMPARE(translator.translate("Main", "Quit"), QString("Fechar"));
        QCOMPARE(translator.translate("Main", "Open"), QString("Abrir"));
        QVERIFY(translator.translate("Main", "Refresh now").isNull());
    }

private:
    static void write(const QString &path, const QByteArray &contents)
    {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(contents);
    }
};

QTEST_MAIN(OllamadashTests)
#include "ollamadash_tests.moc"
