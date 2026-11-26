# Grongigo Perl

A compiler written in Perl for Grongigo, a programming language based on the Grongi language from *Kamen Rider Kuuga* (Masked Rider Kuuga).

## Overview

Grongigo uses C-style declarations, expressions, and control flow with Grongi keywords and operators. Programs compile to Perl by default, or to C with `--target c`.

- Grongi keywords and Katakana identifiers.
- Base-9 numerals with addition and multiplication.
- Perl and C code generation, with token and AST dumps.
- A Perl source filter for running Grongigo with `use Grongigo;`.
- Japanese text conversion, decimal number conversion, and numeral segmentation.

## Usage

### Installation

Requires **Perl 5.36 or later** and core modules only. Running generated C also requires gcc. Save Grongigo source files as UTF-8.

```sh
git clone https://github.com/ydah/grongigo-perl.git
cd grongigo-perl
perl -e 'use v5.36; say $^V'
```

### Compilation

```sh
# Compile to Perl: writes examples/hello.pl
perl bin/grongigo examples/hello.grg

# Compile and run
perl bin/grongigo -r examples/hello.grg

# Choose an output file
perl bin/grongigo -o output.pl examples/factorial.grg

# Compile to C and run with gcc
perl bin/grongigo --target c -r examples/fizzbuzz.grg

# Inspect tokens and the abstract syntax tree
perl bin/grongigo -t -a examples/hello.grg
```

Successful compilation prints `Successfully compiled: INPUT -> OUTPUT`. With `-r`, program output follows `=== Running program ===`.

### Options

| Option | Description |
|---|---|
| `-o, --output FILE` | Output file path; defaults to `.pl` or `.c` beside the source |
| `--target perl\|c` | Output language; defaults to `perl` |
| `-r, --run` | Compile and run; C output requires gcc |
| `-t, --tokens` | Print the token list |
| `-a, --ast` | Print the abstract syntax tree |
| `-v, --verbose` | Print compilation progress |
| `-c, --convert TEXT` | Convert Japanese text to Grongigo |
| `-n, --number NUM` | Convert a decimal integer to Grongigo numerals |
| `--segmentations WORD` | Enumerate every numeral segmentation and its value |
| `-h, --help` | Show help |
| `--version` | Show the compiler version |

### Run Grongigo from Perl

For a file under `demo/`, place these lines before the Grongigo program:

```perl
use FindBin;
use lib "$FindBin::Bin/../lib";
use Grongigo;
```

`use Grongigo;` compiles the following source into Perl. The included demos run directly:

```sh
perl demo/hello.pl
perl demo/factorial.pl
```

## Grongigo Conversion Rules

The `-c` converter accepts hiragana and Katakana and changes consonants according to this table:

| Japanese | Grongigo |
|---|---|
| ア行 | ガ行 |
| カ行 | バ行 |
| サ行 | ガ行 |
| タ行 | ダ行 |
| ナ行 | バ行 |
| ハ行 | ザ行 |
| マ行 | ラ行 |
| ヤ・ユ・ヨ | ジャ・ジュ・ジョ |
| ラ行 | サ行 |
| ワ | パ |
| ガ行 | ガ行 |
| ザ行 | ザ行 |
| ダ行 | ザ行 |
| バ行 | ダ行 |
| パ行 | マ行 |
| ヲ | ゾ |
| ン | ン |

Conversion uses a character table. `ー` is preserved, and `っ` becomes `ッ`. Other unmapped characters are preserved.

These Katakana words are left unchanged: `クウガ`, `リント`, `ゲゲル`, `グロンギ`, `グセパ`, `バグンダダ`, `ゲリザギバスゲゲル`, and `ザギバスゲゲル`.

```sh
perl bin/grongigo -c こんにちは
# ボンビヂザ
```

## Language Specification

### Type Keywords

| Grongigo | C type | Output targets |
|---|---|---|
| ゲギグウ | `int` | Perl, C |
| ロジ | `char` | Perl, C |
| バサ | `void` | Perl, C |
| バゴ | `long` | Perl, C |
| ジジバギ | `short` | Perl, C |
| ブゾウ | `unsigned` | Perl, C |
| ズゾウ | `float` | C |
| ザダダス | `double` | C |

The Perl backend uses scalar variables and integer arithmetic. It omits declaration types from generated Perl and initializes variables without an initializer to zero.

### Control Structures

| Grongigo | Meaning | Output targets |
|---|---|---|
| ジョウベン | `if` | Perl, C |
| ゾバ | `else` | Perl, C |
| ガギザ | `while` | Perl, C |
| ブシバゲギ | `for` | Perl, C |
| ロゾス | `return` | Perl, C |
| ブゲス | `break` | Perl, C |
| ヅヅゲス | `continue` | Perl, C |
| ゲンダブ | `switch` | C |
| ダガギ | `case` | C |
| ビデギ | `default` | C |

An `else if` branch is written as `ゾバ ジョウベン`.

### Built-ins and Literals

| Grongigo | Meaning | Output targets |
|---|---|---|
| ジョウジ | `printf` | Perl, C |
| ジョリドシ | `scanf` | C |
| グンモウ | `sizeof` | C |
| ギン | True (`1`) | Perl, C |
| ビゲ | False (`0`) | Perl, C |
| ルヂ | Null (`undef` in Perl, `NULL` in C) | Perl, C |

When the first argument to `ジョウジ` is a string literal, a newline is added unless it already ends in a newline or `\n`.

### Operators

| Grongigo | Operator | Meaning |
|---|---|---|
| ダグ | `+` | Addition |
| ジブ | `-` | Subtraction |
| バゲス | `*` | Multiplication |
| パス | `/` | Division |
| ガラシ | `%` | Remainder |
| ギセス | `=` | Assignment |
| ジドギギ | `==` | Equal |
| ジドギグバギ | `!=` | Not equal |
| ギョウバシ | `<` | Less than |
| ザギバシ | `>` | Greater than |
| ギバ | `<=` | Less than or equal |
| ギジョウ | `>=` | Greater than or equal |
| バヅ | `&&` | Logical AND |
| ラダパ | `\|\|` | Logical OR |
| ジデギ | `!` | Logical NOT |
| ガンド | `&` | Bitwise AND |
| ゴガ | `\|` | Bitwise OR |
| ダグダグ | `++` | Increment |
| ジブジブ | `--` | Decrement |

Perl output uses integer division: `7 / 2` evaluates to `3`.

### Numbers (Base-9)

Grongigo numerals use base 9, with words derived from English number names:

| Decimal | Base-9 | Grongigo |
|---|---|---|
| 0 | 0 | ゼゼソ |
| 1 | 1 | パパン |
| 2 | 2 | ドググ |
| 3 | 3 | グシギ |
| 4 | 4 | ズゴゴ |
| 5 | 5 | ズガギ |
| 6 | 6 | ギブグ |
| 7 | 7 | ゲズン |
| 8 | 8 | ゲギド |
| 9 | 10 | バギン |

Within a numeral, `ド` adds and `グ` multiplies. For example, `バギンドパパン` is 9 + 1 = 10, and `バギングバギン` is 9 × 9 = 81. Numeric literals in programs use Grongigo numerals. Use `-n` to convert decimal inputs:

```sh
perl bin/grongigo -n 100
# 100 (decimal) = バギングバギンドバギングドググドパパン (Grongigo)
```

Some numeral words have multiple segmentations. Use `--segmentations` to list them:

```sh
perl bin/grongigo --segmentations バギンドドググ
# バギン ド ドググ = 11
# バギン ド ド グ グ = 無効
perl bin/grongigo --segmentations ドググシギ
# ド グ グシギ = 3
```

`無効` marks a segmentation that cannot be evaluated. The lexer normally treats `ドググシギ` as an identifier; the second command finds a segmentation with the value 3.

### Syntax Elements

| Grongigo | Meaning |
|---|---|
| パザ | Function definition marker |
| ゴロ | `main` function |
| ザジレ … ゴパシ | Block (`{ … }`) |
| ジサビバッボ … ドジバッボ | Parentheses (`( … )`) |
| ジサビバブバッボ … ドジバブバッボ | Index brackets (`[ … ]`, C output only) |
| ジサビロジセヅ … ドジロジセヅ | String literal |
| ジサビジドロジ … ドジジドロジ | Character literal |
| 、 | Comma |
| ゴゴ … | Line comment |
| ゴビ … ビゴ | Block comment |

Identifiers use Katakana without Perl sigils: `ギ` becomes `$ギ` in generated Perl. Keywords, operators, and numeric literals use Grongigo words; separators are written as `、` and `：`. ASCII identifiers, numeric literals, and separators are rejected. String and character literals and comment text may contain other characters. Write statements without `。`.

Perl string output recognizes C-style escapes such as `\n`, `\t`, `\r`, `\\`, and `\"`. Octal escapes consume up to three digits, and hexadecimal escapes consume all following hexadecimal digits; numeric escapes decode byte values from 0 to 255. Other backslash sequences and out-of-range numeric escapes are preserved as text.

## Sample Programs

### Hello World

```grg
パザ ゲギグウ ゴロ バサ
ザジレ
    ジョウジ ジサビバッボジサビロジセヅリントンボドバゼドジロジセヅドジバッボ
    ロゾス ゼゼソ
ゴパシ
```

This prints `リントンボドバゼ`. Run [examples/hello.grg](examples/hello.grg) with `perl bin/grongigo -r examples/hello.grg`.

### FizzBuzz

This program prints FizzBuzz for 1 through 15:

```grg
パザ ゲギグウ ゴロ バサ
ザジレ
    ゲギグウ ギ ギセス パパン
    ガギザ ギ ギバ バギンドギブグ
    ザジレ
        ジョウベン ギ ガラシ バギンドギブグ ジドギギ ゼゼソ
        ザジレ
            ジョウジ ジサビバッボジサビロジセヅFizzBuzzドジロジセヅドジバッボ
        ゴパシ
        ゾバ ジョウベン ギ ガラシ グシギ ジドギギ ゼゼソ
        ザジレ
            ジョウジ ジサビバッボジサビロジセヅFizzドジロジセヅドジバッボ
        ゴパシ
        ゾバ ジョウベン ギ ガラシ ズガギ ジドギギ ゼゼソ
        ザジレ
            ジョウジ ジサビバッボジサビロジセヅBuzzドジロジセヅドジバッボ
        ゴパシ
        ゾバ
        ザジレ
            ジョウジ ジサビバッボジサビロジセヅ%dドジロジセヅ、ギ ドジバッボ
        ゴパシ
        ギ ギセス ギ ダグ パパン
    ゴパシ
    ロゾス ゼゼソ
ゴパシ
```

More programs are in [examples/](examples/), including arithmetic, factorials, and FizzBuzz with Grongigo number output.

## Backend Support

Perl output supports scalar variables, functions, integer expressions, conditionals, loops, and `printf`. Arrays, `switch`, `scanf`, `sizeof`, and floating-point types produce compilation errors.

Use an explicit `ロゾス` return statement when a return value matters. Perl's implicit function returns and the return value of `printf` differ from C.

## Tests

```sh
make test
make compare
```

The tests use Perl core modules and include 14 stored output fixtures in `t/golden/`. Select a Perl executable with `make test PERL=/path/to/perl`.

The [CI workflow](.github/workflows/ci.yml) runs tests on Perl 5.36, 5.38, and 5.44 and validates compiled examples.

## File Structure

```text
grongigo-perl/
├── bin/grongigo              # Command-line compiler
├── lib/
│   ├── Grongigo.pm           # Perl source filter
│   └── Grongigo/             # Lexer, parser, numerals, converters and backends
├── examples/                # Grongigo source programs
├── demo/                    # Source-filter examples
├── t/                       # Unit tests and expected output
├── xt/                      # Integration tools
└── .github/workflows/ci.yml  # Continuous integration
```

## License

MIT License. See [LICENSE](LICENSE).

## Acknowledgments

Inspired by *Kamen Rider Kuuga* and the fans who have documented the Grongi language.
