#: test-proxy.pl
#: test and filter out available proxies
#: v0.04
#: Agent2002. Copyright 2004-2005.
#: 2005-01-01 2005-12-08

use strict;
use warnings;

use threads;
use threads::shared;
use Thread::Semaphore;

use LWP::UserAgent;
use HTML::TreeBuilder;  
use Time::HiRes;
use File::Spec;
use Getopt::Std;

my $MAX_THREADS = 10;
my $nthrs : shared = 0;

my %opts;
getopts('ht:s:', \%opts);

if ($opts{h}) {
    print <<_EOC_;
usage: test-proxy <list-file-1> <list-file-2> ...
options:
    -h           print this help to stdout
    -s <string>  string expected to appear in the
                 target web page
                 (default to "O'Reilly")
    -t <url>     the target web page for test,
                 default to http://www.perl.com
_EOC_
    exit(0);
}

my @listfiles = @ARGV or
    die "No input file given.\nUse -h for more help.\n";

my $url = $opts{t} || 'http://www.perl.com';
$url = "http://$url" if $url =~ m/^www/o;
print "Target URL: $url\n";

my $str = $opts{s} || "O'Reilly";
print "Target string: $str\n";

my $logfile = File::Spec->rel2abs('', 'proxy_history.txt');
print "Log File: $logfile\n\n";

my @proxies;
for my $listfile (@listfiles) {
    push @proxies, read_proxy($listfile);
}
die "No proxy found.\n" if not @proxies;
print "\n", scalar(@proxies), " proxies found.\n";

open (my $fh, ">>$logfile") or
    die "Can't write to log file '$logfile': $!\n";
local $| = 1;
print $fh "\n\n" . "==" x 15 . "\n";
print $fh "Time: ".scalar(localtime)."\n";
print $fh "Target Web Site: $url\n\n";

my $thr_sema = Thread::Semaphore->new($MAX_THREADS);
my $tm_sema = Thread::Semaphore->new(1);
my @testres;
warn "Testing the proxies...\n";
foreach my $proxy (@proxies) {
    # warn;
    $thr_sema->down;
    {
        lock($nthrs);
        $nthrs++;
    }
    async {
        my $tid = threads->tid;
        $tm_sema->down;
        my $init = time();
        $tm_sema->up;
        my $ua = LWP::UserAgent->new;
        $ua->timeout(10);
        $ua->proxy(['http', 'ftp'], "http://$proxy");
        warn "$tid: Testing proxy 'http://$proxy'...\n";
        my $res = $ua->get($url);
        unless ($res->is_success and $res->content) {
            warn "$tid: Test failed: ".$res->status_line."\n";
            $thr_sema->up;
            {
                lock($nthrs);
                $nthrs--;
            }
            return undef;
        }
        if ($str) {
            my $pat = quotemeta($str);
            #die $pat;
            if ($res->content !~ m/$pat/) {
                warn "$tid: Test failed: Reponse doesn't match '$str'";
                $thr_sema->up;
                {
                    lock($nthrs);
                    $nthrs--;
                }
                return undef;
            }
        }

        $tm_sema->down;
        my $elapsed = time() - $init;
        $tm_sema->up;
        print $fh "$proxy  =>  $elapsed\n";
        warn "$tid: It seems good: $elapsed sec.\n";
        $thr_sema->up;
        {
            lock($nthrs);
            $nthrs--;
        }
        return ($proxy, $elapsed);
    }
}

# Loop through all the threads 
#foreach my $thr (threads->list) { 
    # Don't join the main thread or ourselves 
#    if ($thr->tid && !threads::equal($thr, threads->self)) { 
#        my ($proxy, $elapsed) = $thr->join;
#        push @testres, [$proxy, $elapsed] if $proxy;
#    } 
#}

while ($nthrs != 0) {
    threads->yield;
}

exit(0);

warn "No proxy available.\n" unless @testres;
@testres = sort { $b->[1] <=> $a->[1] } @testres;
print "\nTest Result ($url):\n";
print $fh "\nTest Result ($url):\n";
foreach (@testres) {
    print "    $_->[0]  =>  $_->[1] sec\n";
    print $fh "    $_->[0]  =>  $_->[1] sec\n";
}
close $fh;

print STDERR "Press any key to continue";
<STDIN>;

0;

sub read_proxy {
    my $fname = shift;
    open my $in, $fname or
        die "error: Cannot open $fname for reading: $!\n";
    my @retvals;
    local $/ = "\n";
    while (<$in>) {
        next if m/^\s*$/o;
        if (m/\b\d+\.\d+\.\d+.\d+:\d{2,4}\b/o) {
            warn "Loading $&...\n";
            push @retvals, $&;
        }
    }
    return @retvals;
}