package WWW::Stress::Command::test;
use Moose;
extends 'WWW::Stress::Command::url';
with 'WWW::Stress::Role::Login';

1;
