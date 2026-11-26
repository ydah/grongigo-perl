package Grongigo::ParseError;
use v5.36;
use overload '""' => sub ($self, @) { $self->{message} }, fallback => 1;

sub new ($class, $message, $token = undef) {
    return bless { message => $message, token => $token }, $class;
}

1;
