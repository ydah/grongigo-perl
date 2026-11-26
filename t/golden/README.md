# Ruby reference output

Generated from `ydah/grongigo` commit `dba84313e7be4ff79d2ad31bc7182fe4c9ed4da1` with `xt/ruby_dump.rb`. The four example files are copied without changes from that commit. The ten boundary inputs in `t/corpus/` cover token boundaries, literals, comments, and parse errors. ASCII source rejection is tested separately in `t/10-lexer.t`, `t/70-compiler.t`, and `t/80-cli.t`.

Regenerate with `make reference && make golden`. These fourteen text files are checked by `t/90-golden.t` without requiring Ruby. Do not update expected output to hide a Perl implementation mismatch.
