package App::lcpan::Cmd::script2rel;

# DATE
# VERSION

use 5.010;
use strict;
use warnings;

require App::lcpan;

our %SPEC;

$SPEC{'handle_cmd'} = {
    v => 1.1,
    summary => 'Get release(s) of script(s)',
    args => {
        %App::lcpan::common_args,
        %App::lcpan::scripts_args,
        %App::lcpan::full_path_args,
        %App::lcpan::all_args,
    },
};
sub handle_cmd {
    my %args = @_;

    my $state = App::lcpan::_init(\%args, 'ro');
    my $dbh = $state->{dbh};

    my $scripts = $args{scripts};
    my $scripts_s = join(",", map {$dbh->quote($_)} @$scripts);

    my $sth = $dbh->prepare("SELECT
  script.name script,
  file.cpanid author,
  file.name release
FROM script
LEFT JOIN file ON script.file_id=file.id
WHERE script.name IN ($scripts_s)
ORDER BY file.id DESC");
    $sth->execute;

    my @res;
    my %mem;
    while (my $row = $sth->fetchrow_hashref) {
        unless ($args{all}) {
            next if $mem{$row->{script}}++;
        }
        if ($args{full_path}) {
            $row->{release} = App::lcpan::_fullpath(
                $row->{release}, $state->{cpan}, $row->{author});
        } else {
            $row->{release} = App::lcpan::_relpath(
                $row->{release}, $row->{author});
        }
        delete $row->{author};
        push @res, $row;
    }

    if (@$scripts == 1) {
        @res = map { $_->{release} } @res;
        if (!@res) {
            return [404, "No such script"];
        } elsif (@res == 1) {
            return [200, "OK", $res[0]];
        } else {
            return [200, "OK", \@res];
        }
    }

    [200, "OK", \@res, {'table.fields' => [qw/script release/]}];
}

1;
# ABSTRACT:
