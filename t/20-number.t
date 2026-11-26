use v5.36;
use utf8;
use Test::More;
binmode Test::More->builder->output, ':encoding(UTF-8)';
binmode Test::More->builder->failure_output, ':encoding(UTF-8)';
use Grongigo::Number qw(parse evaluate segmentations to_grongigo);

for my $case (
    ['ゼゼソ',0], ['パパン',1], ['ドググ',2], ['グシギ',3], ['ズゴゴ',4],
    ['ズガギ',5], ['ギブグ',6], ['ゲズン',7], ['ゲギド',8], ['バギン',9],
    ['バギンドパパン',10], ['バギングバギン',81], ['ド',0], ['ドド',0],
    ['ドパパン',1], ['グパパン',1], ['ゼゼソゼゼソ',undef],
    ['ドググシギ',undef], ['グ',undef], ['パパング',undef],
    ['パパンド',1], ['ゼゼソグバギン',0], ['',undef], ['ヘンスウ',undef],
) {
    is parse($case->[0]), $case->[1], "parse $case->[0]";
}
is_deeply [segmentations('バギンドドググ')], [
    [qw(バギン ド ドググ)], [qw(バギン ド ド グ グ)]
], 'all segmentations, digits before operators';
is_deeply [segmentations('ドググシギ')], [[qw(ド グ グシギ)]], 'backtracking discovers a nongreedy number';
is_deeply [segmentations('')], [], 'no empty segmentation';
is_deeply [segmentations('バギンX')], [], 'no partial segmentation';
is evaluate([qw(バギン ド ドググ)]), 11, 'valid segmentation';
is evaluate([qw(バギン ド ド グ グ)]), undef, 'invalid segmentation';
is evaluate([qw(ド グ グシギ)]), 3, 'nongreedy segmentation value';
is to_grongigo(100), 'バギングバギンドバギングドググドパパン', '100 matches Ruby implementation';
is to_grongigo(0), 'ゼゼソ', 'zero';
is to_grongigo(-1), '', 'preserve Ruby negative-number result';
for my $n (1..1000, 6561, 10000, 1000000) {
    is parse(to_grongigo($n)), $n, "number round trip $n";
}
is parse(to_grongigo('123456789012345678901234567890')), '123456789012345678901234567890', 'arbitrary precision matches Ruby integers';
done_testing;
