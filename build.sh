PROGNAME=${0##*/}

usage() {
    echo "Использование: $PROGNAME <исходный-файл>" >&2
    echo "  Поддерживаются файлы .c, .cpp, .tex" >&2
    exit 64          # EX_USAGE
}

if [ $# -ne 1 ]; then
    echo "$PROGNAME: ошибка: неверное число аргументов" >&2
    usage
fi

SRC=$1

if [ ! -f "$SRC" ]; then
    echo "$PROGNAME: ошибка: файл '$SRC' не найден" >&2
    exit 66          # EX_NOINPUT
fi

if [ ! -r "$SRC" ]; then
    echo "$PROGNAME: ошибка: файл '$SRC' недоступен для чтения" >&2
    exit 77          # EX_NOPERM
fi

case "$SRC" in
    *.c)    KIND=c;   DEFAULT_OUT=${SRC%.c}    ;;
    *.cpp)  KIND=cpp; DEFAULT_OUT=${SRC%.cpp}  ;;
    *.tex)  KIND=tex; DEFAULT_OUT=${SRC%.tex}  ;;
    *)
        echo "$PROGNAME: ошибка: неподдерживаемый тип файла '$SRC'" >&2
        echo "  Ожидается .c, .cpp или .tex" >&2
        exit 65      # EX_DATAERR
        ;;
esac

OUTPUT_NAME=$(
    sed -n 's/^[[:space:]]*\(%\|#\|\/\/\|\/\*\)\?[[:space:]]*Output:[[:space:]]*\([^[:space:]*]*\).*/\2/p' \
        "$SRC" | head -n 1
)

if [ -n "$OUTPUT_NAME" ]; then
    OUT_NAME=$OUTPUT_NAME
else
    echo "$PROGNAME: предупреждение: комментарий 'Output:' не найден," >&2
    echo "  используется имя по умолчанию '$DEFAULT_OUT'" >&2
    OUT_NAME=$DEFAULT_OUT
fi

SRC_DIR=$(cd "$(dirname "$SRC")" && pwd)
SRC_BASE=${SRC##*/}
FINAL_PATH=$SRC_DIR/$OUT_NAME

TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/build.XXXXXX") || {
    echo "$PROGNAME: ошибка: не удалось создать временный каталог" >&2
    exit 73          # EX_CANTCREAT
}

cleanup() {
    rc=$?
    trap - EXIT HUP INT QUIT PIPE TERM
    if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
        rm -rf -- "$TMPDIR"
    fi
    exit $rc
}

trap cleanup EXIT HUP INT QUIT PIPE TERM

cd "$TMPDIR" || {
    echo "$PROGNAME: ошибка: не удалось перейти в '$TMPDIR'" >&2
    exit 73
}

cp -- "$SRC_DIR/$SRC_BASE" "$TMPDIR/$SRC_BASE"

case "$KIND" in
    c)
        echo "$PROGNAME: сборка C-программы '$SRC_BASE' -> '$OUT_NAME'"
        if ! gcc -Wall -Wextra -pedantic -O2 \
                 -o "$OUT_NAME" "$SRC_BASE"; then
            echo "$PROGNAME: ошибка: компиляция не удалась" >&2
            exit 1
        fi
        ;;

    cpp)
        echo "$PROGNAME: сборка C++-программы '$SRC_BASE' -> '$OUT_NAME'"
        if ! g++ -Wall -Wextra -pedantic -O2 \
                 -o "$OUT_NAME" "$SRC_BASE"; then
            echo "$PROGNAME: ошибка: компиляция не удалась" >&2
            exit 1
        fi
        ;;

    tex)
        echo "$PROGNAME: сборка TeX-документа '$SRC_BASE' -> '$OUT_NAME.pdf'"
        if ! pdflatex -interaction=nonstopmode -halt-on-error \
                 "$SRC_BASE" >/dev/null; then
            echo "$PROGNAME: ошибка: сборка TeX не удалась" >&2
            exit 1
        fi

        PDF_BASE=${SRC_BASE%.tex}
        if [ "$PDF_BASE.pdf" != "$OUT_NAME.pdf" ]; then
            mv -f "$PDF_BASE.pdf" "$OUT_NAME.pdf"
        fi
        OUT_NAME=$OUT_NAME.pdf
        ;;
esac

if [ ! -f "$TMPDIR/$OUT_NAME" ]; then
    echo "$PROGNAME: ошибка: результат сборки '$OUT_NAME' не найден" >&2
    exit 1
fi

if ! mv -f -- "$TMPDIR/$OUT_NAME" "$FINAL_PATH"; then
    echo "$PROGNAME: ошибка: не удалось переместить '$OUT_NAME' в '$SRC_DIR'" >&2
    exit 74
fi

echo "$PROGNAME: готово: $FINAL_PATH"
exit 0
