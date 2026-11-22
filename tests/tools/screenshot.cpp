// Loads the real Main.qml offscreen and saves what the window shows.
//
// Usage: screenshot <out.png> [delay-ms]
//
// The delay lets the sparklines fill (60 samples at 2 s). The language file and
// theme directory point nowhere, so the shot is English with the default accent
// whatever this machine is set to.
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>

#include "backend.h"
#include "theme.h"
#include "translator.h"

int main(int argc, char **argv) {
    if (argc < 2)
        return 2;
    qputenv("QT_QPA_PLATFORM", "offscreen");
    QGuiApplication app(argc, argv);
    app.setApplicationVersion(QStringLiteral(APP_VERSION));
    QQuickStyle::setStyle("Material");

    const QString nowhere = QStringLiteral("/nonexistent");
    Translator translator(nowhere, ":/i18n");
    app.installTranslator(&translator);
    Theme theme(nowhere, nullptr, nowhere);
    Backend backend;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("translator", &translator);
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("backend", &backend);
    engine.load(QUrl("qrc:/Main.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;
    backend.start();

    auto *win = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    const QString out = QString::fromLocal8Bit(argv[1]);
    const int delay = argc > 2 ? QString::fromLocal8Bit(argv[2]).toInt() : 5000;
    QTimer::singleShot(delay, [&app, win, out] {
        const bool saved = win->grabWindow().save(out);
        app.exit(saved ? 0 : 1);
    });
    return app.exec();
}
