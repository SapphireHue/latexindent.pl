# Indent.pm
#   contains subroutines for indentation (can be overwritten for each object, if necessary)
package LatexIndent::Indent;
use strict;
use warnings;
use Data::Dumper;
use Exporter qw/import/;
our @EXPORT_OK = qw/indent wrap_up_statement determine_total_indentation indent_body indent_end_statement final_indentation_check push_family_tree_to_indent get_surrounding_indentation/;
our %familyTree;

sub push_family_tree_to_indent{
    my $self = shift;

    %familyTree = %{$self->get_family_tree};
}

sub indent{
    my $self = shift;

    # determine the surrounding and current indentation
    $self->determine_total_indentation;

    # indent the body
    $self->indent_body;

    # indent the end statement
    $self->indent_end_statement;

    # wrap-up statement
    $self->wrap_up_statement;
    return $self;
}

sub wrap_up_statement{
    my $self = shift;
    $self->logger("Finished indenting ${$self}{name}",'heading');
    return $self;
  }

sub determine_total_indentation{
    my $self = shift;

    # calculate and grab the surrounding indentation
    $self->get_surrounding_indentation;

    # logfile information
    my $surroundingIndentation = ${$self}{surroundingIndentation};
    $self->logger("indenting object ${$self}{name}");
    $self->logger("indentation *surrounding* object: '$surroundingIndentation'");
    $self->logger("indentation *of* object: '${$self}{indentation}'");
    $self->logger("*total* indentation to be added: '$surroundingIndentation${$self}{indentation}'");

    # form the total indentation of the object
    ${$self}{indentation} = $surroundingIndentation.${$self}{indentation};

}

sub get_surrounding_indentation{
    my $self = shift;

    my $surroundingIndentation = q();

    if($familyTree{${$self}{id}}){
        $self->logger("ancestors found!");
        foreach(@{${$familyTree{${$self}{id}}}{ancestors}}){
            my $newAncestorId = ${$_}{ancestorID};
            $self->logger("ancestor ID: $newAncestorId, adding indentation of $newAncestorId to surroundingIndentation of ${$self}{id}");
            $surroundingIndentation .= ref(${$_}{ancestorIndentation}) eq 'SCALAR'
                                                ?
                                        (${${$_}{ancestorIndentation}}?${${$_}{ancestorIndentation}}:q())
                                                :
                                        (${$_}{ancestorIndentation}?${$_}{ancestorIndentation}:q());
        }
    }
    ${$self}{surroundingIndentation} = $surroundingIndentation;

}

sub indent_body{
    my $self = shift;

    # grab the indentation of the object
    my $indentation = ${$self}{indentation};

    # output to the logfile
    $self->logger("Body (${$self}{name}) before indentation:\n${$self}{body}","trace");

    # body indendation
    if(${$self}{linebreaksAtEnd}{begin}==1){
        # put any existing horizontal space after the current indentation
        ${$self}{body} =~ s/^(\h*)/$indentation$1/mg;  # add indentation
    } elsif(${$self}{linebreaksAtEnd}{begin}==0 and ${$self}{bodyLineBreaks}>0) {
        if(${$self}{body} =~ m/
                            (.*?)      # content of first line
                            \R         # first line break
                            (.*$)      # rest of body
                            /sx){
            my $bodyFirstLine = $1;
            my $remainingBody = $2;
            $self->logger("first line of body: $bodyFirstLine");
            $self->logger("remaining body (before indentation): '$remainingBody'");
    
            # add the indentation to all the body except first line
            $remainingBody =~ s/^/$indentation/mg unless($remainingBody eq '');  # add indentation
            $self->logger("remaining body (after indentation): '$remainingBody'");
    
            # put the body back together
            ${$self}{body} = $bodyFirstLine."\n".$remainingBody; 
        }
    }

    # output to the logfile
    $self->logger("Body (${$self}{name}) after indentation:\n${$self}{body}","trace");
    return $self;
}

sub indent_end_statement{
    my $self = shift;
    my $surroundingIndentation = (${$self}{surroundingIndentation} and ${$self}{hiddenChildYesNo})
                                            ?
                                 (ref(${$self}{surroundingIndentation}) eq 'SCALAR'?${${$self}{surroundingIndentation}}:${$self}{surroundingIndentation})
                                            :q();

    # end{statement} indentation, e.g \end{environment}, \fi, }, etc
    if(${$self}{linebreaksAtEnd}{body}){
        ${$self}{end} =~ s/^\h*/$surroundingIndentation/mg;  # add indentation
        $self->logger("Adding surrounding indentation to ${$self}{end} ('$surroundingIndentation')");
     }
    return $self;
}

sub final_indentation_check{
    # problem:
    #       if a tab is appended to spaces, it will look different 
    #       from spaces appended to tabs (see test-cases/items/spaces-and-tabs.tex)
    # solution:
    #       move all of the tabs to the beginning of ${$self}{indentation}
    # notes;
    #       this came to light when studying test-cases/items/items1.tex

    my $self = shift;

    my $indentationCounter;
    my @indentationTokens;

    while(${$self}{body} =~ m/^((\h*|\t*)((\h+)(\t+))+)(.*)/mg){
        # replace offending indentation with a token
        $indentationCounter++;
        my $indentationToken = "${$self->get_tokens}{indentation}$indentationCounter";
        my $lineDetails = $6;
        ${$self}{body} =~ s/^((\h*|\t*)((\h+)(\t+))+)/$indentationToken/m;

        $self->logger("Final indentation check: tabs found after spaces -- rearranging so that spaces follow tabs");

        # fix the indentation
        my $indentation = $1;

        # log the before
        (my $before = $indentation) =~ s/\t/TAB/g;
        $self->logger("Indentation before: '$before'");

        # move tabs to the beginning
        while($indentation =~ m/(\h+[^\t])(\t+)/ and $indentation !~ m/^\t*$/  and $1 ne '' and $1 ne "\t"){
            $indentation =~ s/(\h+)(\t+)/$2$1/;

            # log the during
            (my $during = $indentation) =~ s/\t/TAB/g;
            $self->logger("Indentation during: '$during'");
        }

        # log the after
        (my $after = $indentation) =~ s/\t/TAB/g;
        $self->logger("Indentation after: '$after'");

        # store it
        push(@indentationTokens,{id=>$indentationToken,value=>$indentation});
    }

    # loop back through the body and replace tokens with updated values
    foreach (@indentationTokens){
        ${$self}{body} =~ s/${$_}{id}/${$_}{value}/;
    }

}


1;
