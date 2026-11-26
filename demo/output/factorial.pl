use v5.36;
use utf8;
use integer;
binmode STDOUT, ':encoding(UTF-8)';

sub バギジョウシギャス ($バ)
{
    if ((($バ <= 1) ? 1 : 0))
    {
        return 1;
    }
    return ($バ * バギジョウシギャス(($バ - 1)));
}

sub main ()
{
    my $ギ = 0;
    while ((($ギ <= 9) ? 1 : 0))
    {
        printf("%d! = %d\n", $ギ, バギジョウシギャス($ギ));
        ($ギ = ($ギ + 1));
    }
    return 0;
}

exit(main());
