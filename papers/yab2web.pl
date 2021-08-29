#!/usr/bin/perl -w

#################################################################

# yab2web -- yet another tool for converting BibTeX to HTML

# version 1.1 [15/July/2005]

# copyright (C) 2005 -- Nicholas Kushmerick -- kushmerick@gmail.com

# see $yaburl (defined below) for more information

#################################################################

use strict;

use Text::BibTeX; # http://www.gerg.ca/software/btOOL/

## NOTE: there is a bug in Text::BibTeX -- it does not handle
## DOS-style line termination (\r\n) fully, only Unix termination
## (\n).  (specifically, if the value of some bibtext field spans
## multiple lines, then the first line break stays \r\n with the
## others switched to \n.  worse, this bug mucks up its attempt to
## parse names into von, last, etc.)  THEREFORE: DO NOT RUN THIS
## SCRIPT WITH A DOS-STYLE .BIB FILE!  the code attempts to deal with
## the first problem (the spare \r) -- see the use of [:cntrl:] below.
## but it is harder to sort out the second problem.

#################################################################

## PROBABLY no need to change the following

my $debug = 0;

my $yab = "yab2web";


my $tmp = "/tmp";
my $latexfilebase = "$yab";
my $latexfile = "$tmp/$latexfilebase.tex";
my $latexlog = "$tmp/$yab-latex.log";

# my $latex = "/Library/TeX/texbin/latex";
my $latex = "/usr/bin/latex";
my $latex2html = "latex2html";
# my $bibtex = "/Library/TeX/texbin/bibtex";
my $bibtex = "/usr/bin/bibtex";

my $yaburl = "http://www.kushmerick.org/nick/yab2web";

my %filetypes = (pdf  => "PDF",
		 ps   => "Postscript",
		 psgz => "gzip'ed Postscript",
		 html => "HTML",
		 );

my @customBibEntries = ('pdf', 'url', 'image', 'citeulike', 'mendeley', 'publisherversion', 'slides-original', 'slides-converted', 'video', 'video-embedded', 'pubtype', 'project', 'resources', 'authorizer', 'resources-url', 'blogpost');


# these may be overriden with input params

my $output = "index.shtml"; 
my $showyear = 1;
my $sortbyproject = 0;
my $updateDetailPages = 0; # if set to 1, the program will update 
# detail pages for individual papers
my @projectFilter = (); # a list of projects to filter entries by
my @typeFilter = (); # a list of pub types (journal, conference, etc) to filter entries by


#################################################################

## Global vars

my $curYear = 0; # the year of the most recently printed pub
my $detailPageTemplateName = "details.template";
my $detailPageTemplate;

my $metafile;
my @metakeys;

#################################################################

my $res = "";

while (<>) {
    if (/^bibfile\s+(.*)/) {
	$res .= &main(split(/\s/, $1));
    } else {
	$res .= $_;
    }
}

open(OUTPUT, "> $output") || die("[$yab: trouble opening output file $output -- $!]\n");
print OUTPUT $res;
close(OUTPUT);
exit(0);

#################################################################

sub main {
    my ($bibfile) = shift;
    processArgs(@_);
    print "[$yab: using $bibfile]\n";
    my @keys = &gatherKeys($bibfile);
    @metakeys = gatherKeys($metafile) if (defined($metafile));
    print "[$yab: found keys: @keys]\n";
    $bibfile =~ /(.*)\.bib/;
    my $bibbase = $1;
    writeLaTeX($bibbase, @keys);
    print "[$yab: wrote LaTeX]\n";
    runLaTeX($bibfile, $bibbase);
    print "[$yab: ran latex2html]\n";
    my (@rendered) = fetchRendered();
    print "[$yab: found citations]\n";
    my ($body,$pubids,$topicids,$acceptanceids,$topiclist,$venuelist,$yearlist,$authorlist) = makeBody($bibfile, @rendered);
    print "[$yab: created body]\n";
    my $html = &head($pubids,$topicids,$acceptanceids,$topiclist,$venuelist,$yearlist,$authorlist) . $body;
    print "[$yab: added head]\n";
    #$html .= tail($bibfile);
    #print "[$yab: added tail]\n";
    return $html;
}

sub processArgs {
    my @args = @_;
    for(my $i=0; $i <= $#args; $i++) {
	if ($args[$i] eq "-o") {
	    $output = $args[++$i];
	} elsif ($args[$i] eq "-m") {
	    $metafile = $args[++$i];
	} elsif ($args[$i] eq "-y") {
	    $showyear = $args[++$i];
	} elsif ($args[$i] eq "-p") {
	    $sortbyproject = $args[++$i];
	} elsif ($args[$i] eq "-project") {
	    @projectFilter = split(/,/, $args[++$i]);
	} elsif ($args[$i] eq "-type") {
	    @typeFilter = split(/,/, $args[++$i]);
	} elsif ($args[$i] eq "-d") {
	    $updateDetailPages = 1;
	}  

    }
}


sub getBib {
    my ($bibfile) = @_;
    my $bib = new Text::BibTeX::File $bibfile || die "[$yab: trouble opening BibTeX file $bibfile -- $!]\n";
    return $bib;
}



sub gatherKeys {
    my ($bibfile) = @_;
    my @keys= ();
    my $bib = getBib($bibfile);
    my $entry;
    while ($entry = new Text::BibTeX::Entry $bib) {
	next unless $entry->parse_ok;
	next unless $entry->metatype==Text::BibTeX::Entry::BTE_REGULAR;
	push(@keys, $entry->key);
    }
    return sort {-(&findEntry($bibfile,$a)->get('year') <=> &findEntry($bibfile,$b)->get('year'))} @keys;
}


sub writeLaTeX {
    my ($bibbase, @keys) = @_;
    open(LATEX, "> $latexfile") || die("[$yab: trouble with temporary LaTeX file $latexfile -- $!]\n");
    print LATEX "\\documentclass{article}\n\\begin{document}\n";
    foreach my $key (@keys) {
	print LATEX "\\cite{$key}\n";
    }
    # below, unsrt is important -- it ensures that citations occur in chronological order
    print LATEX "\\bibliographystyle{unsrt}\n\\bibliography{" . $bibbase . "}\n\\end{document}\n";
    close(LATEX);
}



sub runLaTeX {
    my ($bibfile, $bibbase) = @_;
    system("echo [$yab: deleting old latex2html files] > $latexlog");
    system("cd $tmp; rm -rf $latexfilebase >> $latexlog");
    system("echo [$yab: running $latex] >> $latexlog");
    system("cd $tmp; $latex $latexfile >> $latexlog");
    system("echo [$yab: copying $bibfile] >> $latexlog");
    system("cp $bibfile $tmp/$bibfile >> $latexlog");
    system("echo [$yab: running $bibtex] >> $latexlog");
    system("cd $tmp; $bibtex $latexfilebase >> $latexlog");
    system("echo [$yab: running $latex2html] >> $latexlog");
    system("cd $tmp; $latex2html $latexfile >> $latexlog");
}


sub fetchRendered {
    open(HTML, "< $tmp/$latexfilebase/node1.html");
    my @html = <HTML>;
    close(HTML);
    my $html = join('', @html);
    # if ($debug) {print("*** Raw HTML:\n=============\n" . $html);}
    $html =~ s/.*DL COMPACT//s;
    my @rendered = ();
    while ($html =~ s/<DT>(.*?)\s*(<\/DL>|\n\n)//s) {
	   push(@rendered, $1);
    }
    return @rendered;
}


sub makeBody {
    my ($bibfile, @rendered) = (@_);
    my $html = '';
    my $even = 0;
    my @pubids = ();
    my @topicids = ();
    my %topiclist = ();
    my %venuelist = ();
    my %yearlist = ();
    my %authorlist = ();
    my @acceptanceids = ();
    foreach my $rendered (@rendered) {
    	my ($morehtml,$pubid,$topicid,$acceptanceid) =
    	    &makeOneEntry($rendered,$bibfile,$even,\%topiclist,\%venuelist,\%yearlist,\%authorlist);
    	$html .= $morehtml;
    	push(@pubids,$pubid) if (defined $pubid);
    	push(@topicids,$topicid) if defined($topicid);
    	push(@acceptanceids,$acceptanceid) if defined($acceptanceid);
    	$even = 1-$even;
    }
    return ($html,\@pubids,\@topicids,\@acceptanceids,\%topiclist,\%venuelist,\%yearlist,\%authorlist);
}



sub makeOneEntry {
    my ($rendered,$bibfile,$even,$topiclist,$venuelist,$yearlist,$authorlist) = (@_);
    # each rendered is of the form:
    # <A NAME="finn-ecml04">1</A>
    # <DD>
    # A.&nbsp;Finn and N.&nbsp;Kushmerick.
    # <BR>Multi-level boundary classification for information extraction.
    # <BR>In <EM>Proc. European Conf. Machine Learning</EM>, 2004.
    if ($debug) {print("*** Rendered:\n==========\n" . $rendered . "\n==============\n");}
    my $key;
    # grab key; different versions of the latex2html use either NAME or ID; somehow I could not use | in the regexp hence the ugliness below
    if($rendered =~ s|.*ID="(.*)".*</A>||) {
	$key = $1;
    } else {
	$rendered =~ s|.*NAME="(.*)".*</A>||;  # grab key
	$key = $1;
    }
    if ($debug) {print("   Key: $key\n  Re-rendered:\n$rendered\n");}

    my @projects = getBibListEntry("project", $key, $bibfile);
    my @types = getBibListEntry("pubtype", $key, $bibfile);
    print STDERR join(", ", @projects) . " <- projects \n";
    return ("") if (($#projectFilter >= 0 && !listOverlap(\@projectFilter, \@projects)) || $#typeFilter >= 0 && !listOverlap(\@typeFilter, \@types));

    $rendered =~ s/.*<DD>\s*//s;           # delete stuff before the rendered proper
    $rendered =~ s/<BR>//sg;               # delete <BR> tags

    $rendered =~ s/[\r\n]/ /g;
    $rendered =~ s/\s\s/ /g;
    $rendered =~ s/\s\s/ /g;
    $rendered =~ s/\s\s/ /g;    
    
    my $title = getTitle($key, $bibfile);
    $title =~ s/[{}]//g;
    my $titleLoc = index(lc($rendered), lc($title));
    my $authors = substr($rendered, 0, $titleLoc - 2);

    my $detailsURL = makeDetailsFile($key, $rendered, $authors, $bibfile, $updateDetailPages);

    my $primary = getBibEntry('pdf', $key, $bibfile);
    if ($primary eq "") {
    	$primary = getPrimaryURL($key, $bibfile);
    }
    if ($primary ne "") {
    	$primary = makeURL($key, $bibfile, $primary);
        $title =~ s/\?/\##/i;        # hack in case title contains a question mark (which would mess up the subsequent title replacement)
        $rendered =~ s/\?/\##/i;
    	$rendered =~ s/$title/<a href=\"$primary\">$title<\/a>/i;
        $title =~ s/\##/\?/i;
        $rendered =~ s/\##/\?/i;
    	$rendered .= "\n";
    }
    my $apup = makeAbstractPopup($key,$bibfile);
    my $links = makeLinks($key,$bibfile, ($apup eq ''));
    my $bpup = makeBibtexPopup($key,$bibfile, ("$apup$links" eq ''));
    my $venue = getVenue($key,$bibfile);
    addToList($venuelist, $venue, $key);
    my $year = getYear($key,$bibfile);
    addToList($yearlist, $year, $key);
    my ($topic,$topicid,$topics) = makeTopic($key,$bibfile);
    my (@topics) = split('\s*;\s*', $topics);
    foreach my $t (@topics) {
	addToList($topiclist, $t, $key);
    }
    my ($acceptance,$acceptanceid) = makeAcceptance($key,$bibfile);
    my @authors = getAuthors($key, $bibfile);
    foreach my $a (@authors) {
	addToList($authorlist, $a, $key);
    }
    my $extras = "$apup$links$bpup$topic$acceptance";
    # note that all of the above are separated by $separator.  for a
    # variety of complicated but important reasons (some are optional;
    # some might have >1 item; others need to be SPANed together with
    # their separator so they can be made to disappear)
    my $pubid = "x$key" . "x"; # see note -@!!!!@-
    # my $html = "<P class=\"paper\" id='$pubid'>$rendered<BR>&nbsp; &nbsp; &nbsp; <SMALL><B style='color:red'>&diams;</B></SMALL>  $extras</P>\n";
    my $html = "<P class=\"paper\" id='$pubid'>$rendered\n";

    # print year header
    if ($showyear && $year != $curYear) {
	$html = "<h4>$year</h4>\n" . $html;
    }
    # any extra notes
    my $award = getBibEntry("award", $key, $bibfile);
    $html .= " <span class=\"award\">&nbsp; $award &nbsp;</span>\n" if ($award ne "");

    # append link to the file with more details
    my $extraInfo = "";
    if (length(getBibEntry("blogpost", $key, $bibfile)) > 0) {
	$extraInfo .= "Blog post, ";
    }
    if (length(getBibEntry("slides-original", $key, $bibfile)) > 0) {
	$extraInfo .= "Slides, ";
    }
    if (length(getBibEntry("video-embedded", $key, $bibfile)) > 0) {
	$extraInfo .= "Video, ";
    }
    if (length(getBibEntry("authorizer", $key, $bibfile)) > 0) {
	$extraInfo .= "Authorizer, ";
    }
    if (length(getBibEntry("resources", $key, $bibfile)) > 0) {
	$extraInfo .= getBibEntry("resources", $key, $bibfile) . ", ";
    }
    if (defined($detailsURL)) {
	$html .= "<br/><span class=\"paperdetails\">[<a href=\"$detailsURL\">Abstract, BibTeX, " . $extraInfo . " etc.</a>]</span>";
    }
    $html .= "</P>\n";

    $curYear = $year;
    return ($html,$pubid,$topicid,$acceptanceid);
}

sub makeSlidesList {
    my $s = $_[0];
    return if (!(defined($s)) || length($s) == 0);
    my @slides = split(/,/, $s);
    my $res = "";
    for(my $i=0; $i<=$#slides; $i++) {
	my $type = "";
	if (index($slides[$i], ".key") >= 0) {
	    $type = "Apple Keynote";
	} elsif (index($slides[$i], ".pptx") >= 0) {
	    $type = "PowerPoint 2007";
	} elsif (index($slides[$i], ".ppt") >= 0) {
	    $type = "PowerPoint";
	} elsif (index($slides[$i], ".swf") >= 0) {
	    $type = "Flash";
	} elsif (index($slides[$i], "full.pdf") >= 0) {
	    $type = "PDF (one slide per animation build)";
	} elsif (index($slides[$i], ".pdf") >= 0) {
	    $type = "PDF";
	} elsif (index($slides[$i], ".mov") >= 0) {
	    $type = "QuickTime (mouse click or button press necessary to advance slides)";
	}
	$res .= "<li><a href=\"$slides[$i]\">$type</a></li>\n";
    }
    return $res;
}

sub makeDetailsFile {
    my ($key, $rendered, $authors, $bibfile, $writethefile) = (@_);

    my $fname = $key . ".shtml";
    $fname =~ s/://;

    my %details;
    $details{'abstract'} = getBibEntry('abstract', $key, $bibfile);
    return if ($details{'abstract'} eq "");
	
    if ($writethefile) {
	$details{'year'} = getYear($key,$bibfile);
	$details{'title'} = getTitle($key, $bibfile);
	$details{'authors'} = $authors;
	$details{'pdf'} = getBibEntry('pdf', $key, $bibfile);
	$details{'pdf'} = makeURL($key, $bibfile, $details{'pdf'}) if (defined($details{'pdf'}) && length($details{'pdf'}) > 0);
	$details{'citation'} = $rendered;
	$details{'image'} = getBibEntry('image', $key, $bibfile);
	$details{'video-embedded'} = getBibEntry('video-embedded', $key, $bibfile);
	$details{'blogpost'} = getBibEntry('blogpost', $key, $bibfile);
	$details{'authorizer'} = getBibEntry('authorizer', $key, $bibfile);
	$details{'publisherVersion'} = getBibEntry('publisherversion', $key, $bibfile);
	$details{'publisher'} = getBibEntry('publisher', $key, $bibfile);
	$details{'citeulike'} = getBibEntry('citeulike', $key, $bibfile);
    $details{'mendeley'} = getBibEntry('mendeley', $key, $bibfile);
	$details{'resources'} = getBibEntry('resources', $key, $bibfile);
	$details{'resources-url'} = getBibEntry('resources-url', $key, $bibfile);
	$details{'bibtexButton'} = makeBibtexPopup($key,$bibfile, 1);
	$details{'slides-original'} = makeSlidesList(getBibEntry('slides-original', $key, $bibfile));
	$details{'slides-converted'} = makeSlidesList(getBibEntry('slides-converted', $key, $bibfile));

	# now create the text of the target page
	if (!defined($detailPageTemplate)) {
	    loadDetailPageTemplate();
	}
	my $page = $detailPageTemplate;
	
	foreach my $key (keys %details) {
	    if (defined($details{$key}) && $details{$key} ne "") {
            #first do a single-line matches (a trick to get it to do shortest matches first)
            $page =~ s/<!--\?\?$key\?\?(.*)\?\?\/$key\?\?-->/$1/ig;
    		$page =~ s/<!--\?\?$key\?\?(.*)\?\?\/$key\?\?-->/$1/sig;
    		$page =~ s/\#\#$key\#\#/$details{$key}/sig;
	    } else {
            $page =~ s/<!--\?\?$key\?\?(.*)\?\?\/$key\?\?-->//ig;
    		$page =~ s/<!--\?\?$key\?\?(.*)\?\?\/$key\?\?-->//sig;
	    }
	}
	
	my $actualFile = $details{'year'} . "/" . $fname;
	if ($debug) {print "about to write $actualFile\n";}
	open DETAILS, ">$actualFile";
	print DETAILS $page;
	close DETAILS;
	chmod 0644, $fname;
    }
    
    return makeURL($key, $bibfile, $fname);
}


sub loadDetailPageTemplate {
    open TEMPL, $detailPageTemplateName;
    while(<TEMPL>) {
	$detailPageTemplate .= $_;
    }
    close TEMPL;
}

sub addToList {
    my ($list, $item, $key)  = @_;
    my $pubid =  "x$key" . "x"; # see note -@!!!!@-
    if (defined(${$list}{$item})) {
       ${$list}{$item} .= ",$pubid";
    } else {
       ${$list}{$item} = "$pubid";
    }
}

## -@!!!!@- To ensure that filters match the right publications, we
## wrap the keys in "x...x".  this ensures that something like
## "smith-XYZ05" doesn't inadvertantly match "smith-XYZ05b".  this
## might sound far-fetched... but it happened to me!


sub getAuthors {
    my ($key,$bibfile)= @_;
    my @authors = ();
    my @places = ('author', 'editor');
    foreach my $place (@places) {
    	foreach my $name (&findEntry($bibfile,$key)->names($place)) {
            if ($debug) {print("Parsing name " . $name . "\n");}
    	    my @vons = $name->part('von') // ();
    	    my @lasts = $name->part('last');
    	    my $author = join(' ', @vons, @lasts);
    	    $author = &htmlify($author);
    	    $author =~ s/ /&nbsp;/g; # err umm, not sure why i do this...
    	    push(@authors, $author);
    	}
    	last if $#authors>0;
    }
    return @authors;

}

sub htmlify {
    my ($thing) = @_;
    # convert latex things like \ss to correspondong iso entities like &szlig;
    return $thing unless $thing =~ /[^[:alpha:][:space:]']/;
    # yes, the following is ugly .. should some day refactor this and the {write,run}LaTeX functions above
    my $latexfilebase2 = $yab . "2";
    my $latex2file = "$tmp/$latexfilebase2.tex";
    my $latex2log = "$tmp/$yab-latex2.log";
    open(LATEX, "> $latex2file") || die("[$yab: htmlifying $thing: trouble with temporary LaTeX file $latex2file -- $!]\n");
    print LATEX "\\documentclass{article}\n\\begin{document}\nBEGINTHING $thing ENDTHING\n\\end{document}";
    close(LATEX);
    system("echo [$yab: htmlifying $thing: deleting old latex2html files] > $latex2log");
    system("cd $tmp; rm -rf $latexfilebase2 >> $latex2log");
    system("echo [$yab: htmlifying $thing: running $latex] >> $latex2log");
    system("cd $tmp; $latex $latex2file >> $latex2log");
    system("echo [$yab: htmlifying $thing: running $latex2html] >> $latex2log");
    system("cd $tmp; $latex2html $latex2file >> $latex2log");
    open(HTML, "< $tmp/$latexfilebase2/index.html");
    foreach (<HTML>) {
	if (/BEGINTHING (.*) ENDTHING/) {
	    my $result = $1;
	    close(HTML);
	    return $result;
	}
    }
    close(HTML);
    die("[$yab: htmlifying $thing: can't find output in $tmp/$latexfilebase2/node1.html]");
}

sub makeAbstractPopup {
    my ($key,$bibfile) = @_;
    my $entry = findEntry($bibfile,$key);
    if ($entry->exists('abstract')) {
	my $astext = $entry->get('abstract');
	return &makePopup("Abstract", $key, $astext, "P");
    } else {
	return '';
    }
}


sub makeBibtexPopup {
    my ($key,$bibfile,$firstextra) = @_;
    my $entry = findEntry($bibfile,$key);
    my $astext = $entry->print_s();
    foreach my $k (@customBibEntries) {
	$astext =~ s/$k\s*=[^\n]+\n//;
    }

    return ($firstextra ? '' : ", ") . &makePopup("BibTeX", $key, $astext, "PRE");
}

sub makePopup {
    my ($label,$key,$text,$tag) = @_;
    $text =~ s/[[:cntrl:]]/\\n/gs;
    $text =~ s/'/\\'/gs;
    $text =~ s/"/\\042/gs;
    return "<A href='#' class='actionbutton' onclick=\"var w=window.open('','$label: $key','scrollbars=yes,menubar=no,height=200,width=600,resizable=yes,toolbar=no,status=no');w.document.writeln('<HTML><HEAD><TITLE>$label: $key</TITLE></HEAD><BODY><$tag>$text</$tag></BODY></HTML>');w.document.close();return false\">$label</A>";
}

sub getVenue {
    my ($key,$bibfile) = @_;
    my %venuemethods = (inproceedings => 'booktitle',
			article => 'journal',
			proceedings => 'title');
    my $entry = findEntry($bibfile,$key);
    my $venue;
    foreach my $type (keys(%venuemethods)) {
	if ($entry->type eq $type) {
	    $venue = $entry->get($venuemethods{$type});
	    last;
	}
    }
    $venue = "Other" unless defined($venue);
    $venue =~ s/[[:cntrl:]]/ /gs;
    $venue =~ s/[[:space:]]+/ /gs;
    return $venue;
}

sub getYear {
    my ($key,$bibfile) = @_;
    my $entry = findEntry($bibfile,$key);
    return $entry->get('year');
}

sub getTitle {
    my ($key,$bibfile) = @_;
    my $entry = findEntry($bibfile,$key);
    my $title = $entry->get('title');
    $title =~ s/[{}]//gs;
    return $title;
}

sub getRawAuthors {
    my ($key,$bibfile) = @_;
    my $entry = findEntry($bibfile,$key);
    return $entry->get('author');
}

sub getBibEntry {
    my ($entryName, $key, $bibfile) = @_;
    my $entry = findEntry($bibfile,$key);
    if ($entry->exists($entryName)) {
	return $entry->get($entryName);
    }
    return "";
}

sub getBibListEntry {
    my ($entryName, $key, $bibfile) = @_;
    my $entry = findEntry($bibfile,$key);
    if ($entry->exists($entryName)) {
	return split(/,/, $entry->get($entryName));
    }
    return ();
}

sub getPrimaryURL {
    my ($key,$bibfile) = @_;
    my $entry = findEntry($bibfile,$key);
    if ($entry->exists('url')) {
	return $entry->get('url');
    }
    return "";
}

# adds all the necessary prefixes to a URL to a file containing some
# detailed content about a paper (pdf, slides, abstract, bibtex, etc)
sub makeURL {
    my ($key,$bibfile, $fileName) = @_;
    # make sure that we are not dealing with an absolute URL
    if (defined($fileName) && index($fileName, "http:\/\/") < 0 && index($fileName, "https:\/\/") < 0) {
	return "papers/" . getYear($key, $bibfile) . "/" . $fileName;
    }
    return $fileName;
}

sub findEntry {
    my ($bibfile,$key) = @_;
    my $bib = getBib($bibfile);
    my $theentry;
    my $entry;
    while ($entry = new Text::BibTeX::Entry $bib) {
    	next unless $entry->parse_ok;
    	next unless $entry->metatype==Text::BibTeX::Entry::BTE_REGULAR;
    	if ($entry->key eq $key) {
    	    $theentry = $entry;
    	    # sigh -- we can't terminate this loop: due to some wierdness in Text::BibTeX, we need to scan the entire file
    	}
    }
    if (not defined $theentry) {
	print STDERR "Did not find an entry for $key\n";
    }
    return $theentry;
}



sub makeLinks {
    my ($key,$bibfile,$firstextra) = @_;
    my $entry = findEntry($bibfile,$key);
    my $links = '';
    my $first = 1;
    foreach my $type (keys(%filetypes)) {
	if ($entry->exists($type)) {
	    my $url = $entry->get($type);
	    $links .= ", " unless ($first && $firstextra);
	    $links .= "<A class='yablink' href='$url'>$filetypes{$type}</A>";
	    $first = 0;
	}
    }
    return $links;
}


sub makeAcceptance {
    my ($key,$bibfile) = @_;
    my $entry = findEntry($bibfile,$key);
    if ($entry->exists('acceptance')) {
	my $filler = $entry->get('acceptance');
	return makeOptional($key, "acceptance", "Acceptance rate", "none", $filler);
    } else {
	return ('', undef);
    }
}

sub makeTopic {
    my ($key,$bibfile) = @_;
    my $entry = findEntry($bibfile,$key);
    if ($entry->exists('topic')) {
	my $topics = $entry->get('topic');
	$topics =~ s/[[:cntrl:]]/ /gs;
	$topics =~ s/[[:space:]]+/ /gs;
	my (@topics) = split('\s*;\s*', $topics);
	my $filler = "";
	foreach my $t (@topics) {
	    $filler .= '; ' if length($filler)>0;
	    $filler .= "<A href='#' class='yablink' onclick='var menu=document.getElementById(\"topicmenu\"); for (var i=0; i<menu.options.length; i++) {if (menu.options[i].innerHTML.indexOf(\"$t\")==0) {menu.value=menu.options[i].value; filter(); break;}} return false'>$t</A>";
	}
	my $topiclabel = 'Topic' . (index($topics,';')>-1 ? 's' : '');
	my ($html, $id) = makeOptional($key, "topic", $topiclabel, "display", $filler);
	return ($html, $id, $topics);
    } else {
	return ('', undef, '');
    }
}

sub makeOptional {
    my ($key, $label, $description, $display, $filler) = @_;
    my $id = "$label-$key";
    my $html = "<SPAN id='$id' style='display:$display'>, $description: $filler</SPAN>";
    return ($html, $id);
}


sub tail {
    my ($bibfile) = (@_);
    my $now = gmtime();
    return "
<HR>
<P align='right'><SMALL>Automatically created from <A href='$bibfile'>$bibfile</A> at $now by <A href='$yaburl'>$yab</A>.</SMALL></P>
<!-- end of content generated by $yab -->
";
}

sub head {
    my ($pubids,$topicids,$acceptanceids,$topiclist,$venuelist,$yearlist,$authorlist) = @_;
    my $head = "
<!-- start of content generated by $yab -->
<SCRIPT>
var pubids = " . &plist2jslist(@{$pubids}) . ";
var menus = [\"topicmenu\", \"venuemenu\", \"yearmenu\", \"authormenu\"];
function filter() {
  displayReset();
  var even = 0;
  for (var i=0; i<pubids.length; i++) {
    var entry = document.getElementById(pubids[i]);
    entry.style.display = 'none'; // safari prayer (seems to have worked!)
    entry.style.display = 'block';
    even = 1-even;
    for (var j=0; j<menus.length; j++) {
      var menu = document.getElementById(menus[j]);
      if (menu.value!='EVERYTHING' && menu.value.indexOf(entry.id)<0) {
        entry.style.display = 'none';
        even = 1-even;
        break;
      }
    }
  }
}
function displayReset() {
  document.getElementById('resetspan').style.visibility = 'hidden';
  if (!document.getElementById('showtopics').checked ||
      document.getElementById('showaccept').checked) {
    document.getElementById('resetspan').style.visibility = 'visible';
  } else {
    for (var j=0; j<menus.length; j++) {
      if (document.getElementById(menus[j]).value != 'EVERYTHING') {
        document.getElementById('resetspan').style.visibility = 'visible';
        break;
      }
    }
  }
}
function resetFilters() {
    document.getElementById('showtopics').checked = true;
    document.getElementById('showaccept').checked = false;
    for (var j=0; j<menus.length; j++) {
      document.getElementById(menus[j]).value = 'EVERYTHING';
    }
    displayReset();
    filter();
}
</SCRIPT>
";
    return $head;
}

sub makeMenu {
    my ($label, $id, $items, $plural, $descending) = @_;
    my $x = "<TD align='right'>$label:</TD>
             <TD><SELECT style='width:8cm' id='$id' onChange='filter()'> 
             <OPTION selected value='EVERYTHING'>$plural</OPTION>\n";
    my @keys = sort(keys(%{$items}));
    if ($descending) {
	@keys = reverse(@keys);
    }
    foreach my $item (@keys) {
        my $keys = ${$items}{$item}; # $keys of the form "jones-abc98,smith-xyz05,johnson-pqr01"
        my $nkeys = () = ($keys =~ /,/g);
        $nkeys++; # n commas ==> n+1 things
	$x .= "<OPTION value='$keys'>$item &nbsp; ($nkeys)</OPTION>\n";
    }
    return "$x</SELECT></TD>";
}

sub makeCheckbox {
    my ($id, $idlist, $things, $checked) = @_;
    return "<TD><INPUT id='$id' type='checkbox' $checked onChange='var ids=" . &plist2jslist(@{$idlist}) . "; var d=checked?\"inline\":\"none\"; for (var i=0; i<ids.length; i++) {var s = document.getElementById(ids[i]).style; s.display=d;} resetDisplay();'>Show $things?</TD>"; 
}

sub plist2jslist {
    my (@list) = @_;
    my $string = '[';
    my $first = 1;
    foreach my $x (@list) {
 	$string .= "," unless $first;
 	$string .= "\"$x\"";
 	$first = 0;
    }
    $string .= ']';
    return $string;
}

# checks if there is at least one shared element between two lists
sub listOverlap {
    my @l1 = @{$_[0]};
    my @l2 = @{$_[1]};
    for (my $i = 0; $i <= $#l1; $i++) {
	for (my $j = 0; $j <= $#l2; $j++) {
	    return 1 if ($l1[$i] eq $l2[$j]);
	}
    }
    return 0;
}

#################################
# yab2web TO-DO list
# - safari flakiness? (please let me know if you notice problems with
#   safari or other browsers.)
# - body onload so that filters are synched with display on back button etc
# - instead of select.onchange use something else so that using arrow
#   keys to navigate the menus causes immediate change, don't need to
#   wait til the select loses focus.
# - too many separate invocations of LaTeX (one per funny
#   author/editor) at least cache them in case they re-appear; or do
#   them en masse
# - create alternative web-based interface so people can try it
#   without installing it locally
# - there is a problem with MS-IE complaining about missing ',' -- probably can't handle very long javascript lines?
#################################
