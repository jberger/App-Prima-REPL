use strict;
use warnings;

package ih;
use constant Null    =>  0;
use constant StdOut  =>  1;

use constant Unique  => 10;
use constant All     => 11;
use constant NoRepeat => 12;

#########################################
# Prima::Ex::InputHistory::Output::Null #
#########################################
# A ridiculously simple output handler that does nothing
package Prima::Ex::InputHistory::Output::Null;
sub printout { }
sub newline_printout { }
sub new {my $self = {}; return bless $self}

###########################################
# Prima::Ex::InputHistory::Output::Simple #
###########################################
# The default output handler with which InputHistory works; uses Perl's print
# statement for output.
package Prima::Ex::InputHistory::Output::StdOut;
sub printout {
	my $self = shift;
	print @_;
	if (defined $_[-1]) {
		$self->{last_line} = $_[-1];
	}
	else {
		$self->{last_line} = '';
	}
}
sub newline_printout {
	my $self = shift;
	if ($self->{last_line} !~ /\n$/) {
		$self->printout("\n", @_);
	}
	else {
		$self->printout(@_);
	}
}
sub new {
	my $self = {last_line => ''};
	return bless $self
}


###########################
# Prima::Ex::InputHistory #
###########################
# a history-tracking input line.
package Prima::Ex::InputHistory;
use base 'Prima::InputLine';

# This has the standard profile of an InputLine widget, except that it knows
# about history files, which will require a bit of work in the init section.
sub profile_default
{
	my %def = %{$_[ 0]-> SUPER::profile_default};

	# These lines are somewhat patterned from the Prima example called 'editor'
	my @acc = (
		# Navigation scrolls through the command history
		  ['Previous Line', 'Up', kb::Up, sub {$_[0]->move_line(-1)}]
		, ['Next Line', 'Down', kb::Down, sub {$_[0]->move_line(1)}]
		# Note that the values of 10 here are purely symbolic; the function
		# actually refers to self's pageLines property when it sees +-10
		, ['Earlier Lines', 'Page Up', kb::PageUp, sub {$_[0]->move_line(-10)}]
		, ['Later Lines', 'Page Down', kb::PageDown, sub {$_[0]->move_line(10)}]
		# Enter runs the line
		, ['Run', 'Return', kb::Return, sub {$_[0]->PressEnter}]
		, ['Run', 'Enter', kb::Enter, sub {$_[0]->PressEnter}]
	);

	return {
		%def,
		fileName => '.prima.history',
		pageLines => 10,		# lines to 'scroll' with pageup/pagedown
		historyLength => 200,	# total number of lines to save to disk
		accelItems => \@acc,
		outputWidget => ih::StdOut,
		promptFormat => '> ',
		currentLine => 0,
		storeType => ih::All,
	}
}

# This stage initializes the inputline. I believe this is the appropriate stage
# for (1) setting the properties above (2) loading the history file data, and
# (3) connecting to the output widget.
sub init {
	my $self = shift;
	my %profile = $self->SUPER::init(@_);
	my $fileName = $self->{fileName} = $profile{fileName};
	foreach ( qw(pageLines historyLength promptFormat currentLine outputWidget
				storeType) ) {
		$self->{$_} = $profile{$_};
	}
	
	# Open the file and set up the other internal data:
	my @history;
	if (-f $fileName) {
		open my $fh, '<', $fileName;
		while (<$fh>) {
			chomp;
			push @history, $_;
		}
		close $fh;
	}

	# Store the history and revisions:
	$self->history(\@history);
	$self->currentRevisions([]);
	$self->currentLine(0);
	
	# Set up the output widget. Perl scalars with text are not allowed:
	if (not ref($profile{outputWidget}) and $profile{outputWidget} !~ /^\d+$/) {
		croak("Unknown outputWidget $profile{outputWidget}");
	}
	elsif ($profile{outputWidget} == ih::Null) {
		$self->{outputWidget} = new Prima::Ex::InputHistory::Output::Null;
	}
	elsif ($profile{outputWidget} == ih::StdOut) {
		$self->{outputWidget} = new Prima::Ex::InputHistory::Output::StdOut;
	}
	else {
		# Make sure it can do what I need:
		use Carp 'croak';
		croak("Unknown outputWidget does not appear to be an object")
			unless ref($profile{outputWidget});
		croak("outputWidget must have methods printout and newline_printout")
			unless $profile{outputWidget}->can('printout')
				and $profile{outputWidget}->can('newline_printout');
		# Add it to self
		$self->{outputWidget} = $profile{outputWidget};
	}

	return %profile;
}

# This stage pretty much does away with the object. I want to save the results
# to the history file as a last step before going down. Note that the super's
# done function is called *after* this has exectued:
sub done {
	my $self = shift;
	
	# Save the last N lines in the history file:
	open my $fh, '>', $self->{fileName};
	# I want to save the *last* 200 lines, so I don't necessarily start at
	# the first entry in the history:
	my $offset = 0;
	my @history = @{$self->{history}};
	my $historyLength = $self->{historyLength};
	$offset = @history - $historyLength if (@history > $historyLength);
	while ($offset < @history) {
		print $fh $history[$offset++], "\n";
	}
	close $fh;
	
	# All done. Call the super's done function:
	$self->SUPER::done;
}

# Changes the contents of the evaluation line to the one stored in the history.
# This is used for the up/down key callbacks for the evaluation line. The
# currentRevisions array holds the revisions to the history, and it is reset
# every time the user runs the evaluation line.
sub move_line {
	my ($self, $requested_move) = @_;
	
	# Set the move to the pageLines number of lines if 10/-10 was requested:
	$requested_move = $self->pageLines if $requested_move == 10;
	$requested_move = -$self->pageLines if $requested_move == -10;
	
	# Determine the requested line number. (currentLine counts backwards)
	my $line_number = $self->currentLine() - $requested_move;
	
	# Don't cycle:
	my $history_length = scalar @{$self->history};
	$line_number = 0 if $line_number < 0;
	$line_number = $history_length if $line_number > $history_length;
	
	# and go there
	$self->currentLine($line_number);
}

# The class properties. Template code for these was taken from Prima::Object's
# name example property code:
sub fileName {
	return $_[0]->{fileName} unless $#_;
	$_[0]->{fileName} = $_[1];
}
sub pageLines {
	return $_[0]->{pageLines} unless $#_;
	$_[0]->{pageLines} = $_[1];
}
sub historyLength {
	return $_[0]->{historyLength} unless $#_;
	$_[0]->{historyLength} = $_[1];
}
sub promptFormat {
	return $_[0]->{promptFormat} unless $#_;
	$_[0]->{promptFormat} = $_[1];
}
sub outputWidget {
	return $_[0]->{outputWidget} unless $#_;
	$_[0]->{outputWidget} = $_[1];
}
sub history {
	return $_[0]->{history} unless $#_;
	$_[0]->{history} = $_[1];
}
sub currentRevisions {
	return $_[0]->{currentRevisions} unless $#_;
	$_[0]->{currentRevisions} = $_[1];
}
sub storeType {
	return $_[0]->{storeType} unless $#_;
	$_[0]->{storeType} = $_[1];
}

# Gets or sets the current line number, counting backwards. The current line of
# text is considered to be at 0; the previous entry is 1, etc. This handles all
# the intermediate storage and text swapping.
sub currentLine {
	return $_[0]->{currentLine} unless $#_;
	my ($self, $line_number) = @_;
	
	# Save changes to the current line in the revision list:
	$self->currentRevisions->[$self->{currentLine}] = $self->text;
	
	# Get the current character offset:
	my $curr_offset = $self->charOffset;
	# Note the end-of-line position by zero:
	$curr_offset = 0 if $curr_offset == length($self->text);
	
	# make sure the requested line makes sense; cycle if it doesn't, and just
	# set to zero if there is no history:
	my $last_line = scalar @{$self->history};
	if ($last_line) {
		$line_number += $last_line while $line_number < 0;
		$line_number -= $last_line while $line_number > $last_line;
	}
	else {
		$line_number = 0;
	}
	
	# Set self's current line:
	$self->{currentLine} = $line_number;
	
	# Load the text using the Orcish Maneuver:
	my $new_text = $self->currentRevisions->[$line_number]
						//= $self->history->[-$line_number];
	$self->text($new_text);
	
	# Put the cursor at the previous offset. However, if the previous offset
	# was zero, put the cursor at the end of the line:
	$self->charOffset($curr_offset || length($new_text));
	
	return $line_number;
}

# Add a new notification_type for each of on_Enter and on_Evaluate. The first
# should be set with hooks that remove or modify any text that needs to be
# cleaned before the eval stage. In other words, if you want to define commands
# that do not parse as a function in Perl, add it as a hook under on_Enter. The
# best examples I can think of, which also serve to differentiate between the
# two needs, are NiceSlice processing, and processing the help command. To make
# help work as a bona-fide function, you would have to surround your topic with
# quotes:
#   help 'PDL::IO::FastRaw'
# That's ugly. It would be much nicer to avoid the quotes, if possible, with
# something like this:
#   help PDL::IO::FastRaw
# That's the kinda thing you would handle with an on_Enter hook. After the help
# hook handles that sort of thing, it then calls the clear_event() method on the
# InputHistory object. On the other hand, NiceSlice parsing will modify the
# contents of the evaluation, but not call clear_event because it wants the
# contents of the text to be passed to the evaluation.
#
# If the event is properly handled by one of the hooks, the hook should call the
# clear_event() method on this object.
{
	# Keep the notifications hash in its own lexically scoped block so that
	# other's can't mess with it (at least, not without using PadWalker or some
	# such).
	my %notifications = (
		%{Prima::InputLine-> notification_types()},
		PressEnter => nt::Request,
		Evaluate => nt::Action,
	);
	
	sub notification_types { return \%notifications }
}

# When issuing on_Enter, check for the return value. If it was 1, that means
# the text was handled and clear_event was called. In that case, I do not need
# to issue the on_Evaluate event since the text was already handled.

# Issues the on_Evaluate notification. The default evaluation is pretty lame -
# it just prints the result of evaling the text using the print command.
sub Evaluate {
	my ($self, $text) = @_;
	$_[0]->notify('Evaluate', $text);
}

sub on_evaluate {
	my ($self, $text) = @_;
	my $results = eval ($text);
	$self->outputWidget->printout($results) if defined $results;
	$self->outputWidget->printout('undef') if not defined $results;
}

# Issues the on_Enter notification, which starts with the class's method. The
# return value here is important and determines whether or not to proceed to the
# evaluation stage:
sub PressEnter {
	my $self = shift;
	# Get a copy of the text from the widget.
	my $text = $self->text;
	# Call the hooks, allowing them to modify the text as they go:
	my $needs_to_eval = $self->notify('PressEnter', $text);
	return unless $needs_to_eval;
	# If we're here, we need to eval the code:
	$self->Evaluate($text);
}

# This is the object's method for handling PressEnter events. Its job is to
# handle all of the history-related munging. It does not change the contents of
# the text, so it is safe to unpack the text. (Hooks that intend to modify the
# text must work directly with $_[1].)
sub on_pressenter {
	my ($self, $text) = @_;

	# Remove the endlines, if present, replacing them with safe whitespace:
	$text =~ s/\n/ /g;
	
	# Reset the current collection of revisions:
	$self->{currentRevisions} = [];
	
	# print this line:
	$self->outputWidget->newline_printout($self->promptFormat, $text, "\n");

	# We are about to add this text to the history. Before doing so, check if
	# the history needs to be modified before performing the add:
	if ($self->storeType == ih::NoRepeat and $self->history->[-1] eq $text) {
		# remove the previous entry if it's identical to this one:
		pop @{$self->history};
	}
	elsif ($self->storeType == ih::Unique) {
		# Remove all the other identical entries if they are the same is this:
		$self->history([ grep {$text ne $_} @{$self->history} ]);
	}

	# Add the text as the last element in the entry:
	push @{$self->history}, $text;
	
	# Remove the text from the entry
	$self->text('');
	
	# Set the current line to the last one:
	$self->{currentLine} = 0;
}

1;
