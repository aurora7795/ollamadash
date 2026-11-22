QT += core gui qml quick quickcontrols2 network

CONFIG += c++17 release
TARGET = ollamadash
# The one place the version lives besides pkgbuild/PKGBUILD; the window shows it.
VERSION = 0.1.2
DEFINES += APP_VERSION=\\\"$$VERSION\\\"
TEMPLATE = app

HEADERS += \
    src/backend.h \
    src/theme.h \
    src/translator.h

SOURCES += \
    src/main.cpp \
    src/backend.cpp \
    src/theme.cpp \
    src/translator.cpp

RESOURCES += src/resources.qrc
