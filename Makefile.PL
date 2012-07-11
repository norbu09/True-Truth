use inc::Module::Install;

name     'True-Truth';
all_from 'lib/True/Truth.pm';
author   q{Lenz Gschwendtner <norbu09@cpan.org>};
license  'perl';

build_requires 'Test::More';

requires 'Redis';
requires 'Storable';
requires 'MIME::Base64';
requires 'Any::Moose';

WriteAll;

