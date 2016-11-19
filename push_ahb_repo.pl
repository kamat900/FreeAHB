#!/usr/bin/perl -w

print "Enter comment for AHB repo...\n";
my $comment = <STDIN>;

die "*E: GIT STATUS FAILED...\n" if system("git status");
die "*E: GIT ADD FAILED...\n" if system("git add .");
die "*E: GIT COMMIT FAILED...\n" if system("git commit -m \"$comment\"");
die "*E: GIT PUSH ORIGIN MASTER FAILED...\n" if system("git push origin master");

print "All OK!\n";

exit 0;
