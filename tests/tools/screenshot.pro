QT += core gui qml quick quickcontrols2 network
CONFIG += c++17
TARGET = screenshot
TEMPLATE = app

SRC = $$PWD/../../src
INCLUDEPATH += $$SRC
# bin/screenshot passes VERSION from ollamadash.pro on the qmake command line.
isEmpty(VERSION): VERSION = dev
DEFINES += APP_VERSION=\\\"$$VERSION\\\"
HEADERS += $$SRC/backend.h $$SRC/theme.h $$SRC/translator.h
SOURCES += screenshot.cpp $$SRC/backend.cpp $$SRC/theme.cpp $$SRC/translator.cpp
RESOURCES += $$SRC/resources.qrc
