QT += core gui quick quickcontrols2 network testlib
CONFIG += c++17 testcase
TARGET = ollamadash_tests
TEMPLATE = app

INCLUDEPATH += ../src

HEADERS += ../src/backend.h ../src/theme.h ../src/translator.h
SOURCES += ollamadash_tests.cpp ../src/backend.cpp ../src/theme.cpp ../src/translator.cpp

# Lets the catalog test read the real translation files.
DEFINES += I18N_DIR=\\\"$$PWD/../src/i18n\\\"
