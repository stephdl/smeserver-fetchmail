#----------------------------------------------------------------------
# $Id: fetchmail.pm,v 1.3.3 2004/05/09 21:00:00 pschirrmann 
# vim: ft=perl ts=4 sw=4 et:
#----------------------------------------------------------------------
# copyright (C) 2004 Pascal Schirrmann
# copyright (C) 2002 Mitel Networks Corporation
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA
#----------------------------------------------------------------------

package esmith::FormMagick::Panel::fetchmail;

use strict;
use esmith::ConfigDB;
use esmith::AccountsDB;
use esmith::DB::db;
use esmith::FormMagick;
use esmith::cgi;
use Exporter;

use constant TRUE => 1;
use constant FALSE => 0;

our @ISA = qw(esmith::FormMagick Exporter);

our @EXPORT = qw(
     new
    );

our $VERSION = sprintf '%d.%03d', q$Revision: 0.03 $ =~ /: (\d+).(\d+)/;
our $db = esmith::ConfigDB->open
        or die "Can't open the Config database : $!\n" ;
our $accountdb = esmith::AccountsDB->open
        or die "Can't open the Account database : $!\n" ;

# fields and records separator for sub records
use constant FS => "," ;
use constant RS => ";" ;

=head1 NAME

esmith::FormMagick::Panels::fetchmail - useful panel functions

=head1 SYNOPSIS

    use esmith::FormMagick::Panels::fetchmail

    my $panel = esmith::FormMagick::Panel::fetchmail->new();
    $panel->display();

=head1 DESCRIPTION

This module is the backend to the fetchmail panel, responsible for
supplying all functions used by that panel. It is a subclass of
esmith::FormMagick itself, so it inherits the functionality of a FormMagick
object.

=head2 new

This is the class constructor.

=cut

sub new {
    my $class = ref($_[0]) || $_[0];
    my $self = esmith::FormMagick->new();
    bless $self, $class;
    # Uncomment the following line for debugging.
    #$self->debug(TRUE);
    return $self;
}

=head2 get_temp_rec

This method, called by differents functions on page 1 and 2, open
the temp database, or create the database if needed.
it create a temporary record if needed.
The method return a link to the record '$.id'.

=cut

sub get_temp_rec {
    my $self = shift ;
    $self->debug_msg("'get_temp_rec' begins.") ;
    my $q    = $self->{cgi} ;
    my $id   = $q->param('.id') ;
    $self->debug_msg("\$id = $id.") ;
    my $base = "/home/e-smith/db/fetchmail_temp.db" ;
    $self->debug_msg("\$base = $base.") ;
    my $db   = '' ;
    if (  -e $base ) {
        $db = esmith::DB::db->open($base) or
            die esmith::DB::db->error ;
    } else {
        $db = esmith::DB::db->create($base) or
            die esmith::DB::db->error ;
    }
    $self->debug_msg("$base is open.") ;
    if ( ! ( defined $db->get($id) ) ) {
        my %vals = ( 'type' => 'misc', 
                     'date' => time );
        my $r = $db->new_record($id, \%vals) or 
            die esmith::DB::db->error ;
    }
    my $rec = $db->get($id) ;
    $self->debug_msg("'get_temp_rec' ends.") ;
    return $rec ;
}

=head2 temp_database_cleanup

This method removes records older than one days in the
temporary database, if any

=cut

sub temp_database_cleanup {
    my $self = shift ;
    $self->debug_msg("'temp_database_cleanup' begins.") ;
    my $base = "/home/e-smith/db/fetchmail_temp.db" ;
    $self->debug_msg("\$base = $base.") ;
    my $removed = 0 ;
    my $db   = '' ;
    if (  -e $base ) {
        $db = esmith::DB::db->open($base) or
            die esmith::DB::db->error ;
        my @all_records = $db->get_all ;
        my $now = time ;
        foreach my $rec ( @all_records ) { 
            if ( ( $now - $rec->prop('date') ) > 86400 ) {
                $removed++ ;
                $rec->delete ;
            } 
        }
    }
    $self->debug_msg("'temp_database_cleanup' ends.") ;
    return $removed ;
}

=head2 get_field

This method retrive a field value, to put then in another field
on another page.

=cut

sub get_field
{
    my $self = shift;
    my $item = shift;

    return $self->{cgi}->param($item) || '';
}

=head2 show_fetchmail_status

This method show the current status of fetchmail (enabled or disabled)
and allow the status change

=cut

sub show_fetchmail_status {
    my $self = shift ;
    my $q = $self->{cgi} ;

    my $FM = $db->get('FetchMails')
        or ($self->error('ERR_NO_FETCHMAIL_RECORD') and return undef) ;
    my $FMStatus = 0 ;
    $FMStatus = 1 if ( ( $FM->prop('status') || 'disabled' ) eq 'enabled' ) ;
    my $FMRouting = 0 ;
    $FMRouting = 1 if ( ( $FM->prop('Routing') || 'NO' ) eq 'YES' ) ;
    my $FMRoutingSMTP = 0 ;
    $FMRoutingSMTP = 1 if ( ( $FM->prop('RoutingSMTP') || 'NO' ) eq 'YES' ) ;
    my $FMRoutingNNTP = 0 ;
    $FMRoutingNNTP = 1 if ( ( $FM->prop('RoutingNNTP') || 'NO' ) eq 'YES' ) ;
    # we need also information about smtpfront-qmail
    # PS 2005/08/02 -> 1.3.4-05
    # SME7 no longer use smtpfront-qmail, but use smtpd instead
    my $SysConfig = $db->get('sysconfig') ;
    my $SMEVersion = ( $SysConfig->prop('ReleaseVersion') || 0 ) ;
    $SMEVersion =~ s/^(\d+)\..*$/$1/ ;
    my $MailSystem = 'smtpfront-qmail' ;
    $MailSystem = 'smtpd' if ( $SMEVersion > 6 ) ;
    $self->debug_msg("'fetchmail_SMTPProxy' : Major Version = $SMEVersion - Mailsystem = $MailSystem.") ;
    my $SmtpProxy = $db->get($MailSystem) 
        or ($self->error('ERR_NO_SMTPFRONT-QMAIL_RECORD') and return undef) ;
    my $FMRoutingSMTPProxy = 0 ;
    $FMRoutingSMTPProxy = 1 if ( ( $SmtpProxy->prop('Proxy') || 'disabled' ) eq 'enabled' ) ;
    print $q->start_table({-class => 'sme-noborder'}), "\n";
    print $q->Tr(
        esmith::cgi::genCell( $q,
        "<img align=\"right\" src=\"/server-common/Light_" . $FMStatus . ".jpg\" ALT=\"" .
            $self->localise('STATUS_' . $FMStatus) . "\">" ),
        esmith::cgi::genCell( $q,
            $self->localise('SERVICE_' . $FMStatus) , "sme-noborders-label" ),
        esmith::cgi::genCell( $q, "<a class=\"button-like\""
            . "href=\"fetchmail?page=5&Next=First&Current=" . $FMStatus . "\">"
            . $self->localise('BUTTON_LABEL_SERVICE_' . $FMStatus )
            . "</a>", "sme-noborders-content" ),"\n",
    ),"\n" ;
    print $q->Tr(
        esmith::cgi::genCell( $q,
        "<img align=\"right\" src=\"/server-common/Light_" . $FMRouting . ".jpg\" ALT=\"" .
            $self->localise('STATUS_' . $FMRouting) . "\">" ),
        esmith::cgi::genCell( $q,
            $self->localise('ROUTING_' . $FMRouting) , "sme-noborders-label" ),
        esmith::cgi::genCell( $q,
            "<a class=\"button-like\""
            . "href=\"fetchmail?page=6&Next=First&CurrentPOP=" . $FMRouting . "\">"
            . $self->localise('BUTTON_LABEL_ROUTING_' . $FMRouting)
            . "</a>" , "sme-noborders-content" ),"\n",
    ),"\n" ;
    print $q->Tr(
        esmith::cgi::genCell( $q,
        "<img align=\"right\" src=\"/server-common/Light_" . $FMRoutingNNTP . ".jpg\" ALT=\"" .
            $self->localise('STATUS_' . $FMRoutingNNTP) . "\">" ),
        esmith::cgi::genCell( $q,
            $self->localise('ROUTINGNNTP_' . $FMRoutingNNTP) , "sme-noborders-label" ),
        esmith::cgi::genCell( $q,
            "<a class=\"button-like\""
            . "href=\"fetchmail?page=8&Next=First&CurrentNNTP=" . $FMRoutingNNTP . "\">"
            . $self->localise('BUTTON_LABEL_ROUTINGNNTP_' . $FMRoutingNNTP)
            . "</a>" , "sme-noborders-content" ),"\n",
    ),"\n" ;
     print $q->Tr(
        esmith::cgi::genCell( $q,
        "<img align=\"right\" src=\"/server-common/Light_" . $FMRoutingSMTP . ".jpg\" ALT=\"" .
            $self->localise('STATUS_' . $FMRoutingSMTP) . "\">" ),
        esmith::cgi::genCell( $q,
            $self->localise('ROUTINGSMTP_' . $FMRoutingSMTP) , "sme-noborders-label" ),
        esmith::cgi::genCell( $q,
            "<a class=\"button-like\""
            . "href=\"fetchmail?page=7&Next=First&CurrentSMTP=" . $FMRoutingSMTP . "\">"
            . $self->localise('BUTTON_LABEL_ROUTINGSMTP_' . $FMRoutingSMTP)
            . "</a>" , "sme-noborders-content" ),"\n",
    ),"\n" ;
    print $q->Tr(
        esmith::cgi::genCell( $q,
        "<img align=\"right\" src=\"/server-common/Light_" . $FMRoutingSMTPProxy . ".jpg\" ALT=\"" .
            $self->localise('STATUS_' . $FMRoutingSMTPProxy) . "\">" ),
        esmith::cgi::genCell( $q,
            $self->localise('ROUTINGSMTPPROXY_' . $FMRoutingSMTPProxy) , "sme-noborders-label" ),
        esmith::cgi::genCell( $q,
            "<a class=\"button-like\""
            . "href=\"fetchmail?page=9&Next=First&CurrentSMTPProxy=" . $FMRoutingSMTPProxy . "\">"
            . $self->localise('BUTTON_LABEL_ROUTINGSMTPPROXY_' . $FMRoutingSMTPProxy)
            . "</a>" , "sme-noborders-content" ),"\n",
    ),"\n" ;
    print $q->end_table(),"\n";
    return undef ;
}

=head2 show_button_validate

This method is only here to install a button in a
FormMagick Form

=cut

sub show_button_validate {
    my $self = shift ;
    my $q = $self->{cgi} ;
    return "<input type=\"submit\" name=\"valid_account\" value=\""
           . $self->localise('BUTTON_LABEL_VALIDATE_ACCOUNT' ) . "\">" ;
}

=head2 show_fetchmail_users

This method displays the lists of users on the system, and 
summarize the fetchmail status.
Here we can also modify a user configuration

=cut

sub show_fetchmail_users {
    my $self = shift ;
    my $q = $self->{cgi} ;
    $self->debug_msg("show_fetchmail_users begins.") ;
    
    # for debugging purposes only...
    # PS 2005 Oct 22 : sessiondir() is no longer present, and this information was 
    # for debug use only anyway...
    # my $sessiondir = $self->sessiondir();
    # $self->debug_msg("The session dir is $sessiondir .") ;

    # retrieve users Data...
    my @users = $accountdb->get('admin');
    push @users, $accountdb->users();

    unless ( scalar @users )
    {
        print $q->Tr($q->td($self->localise('NO_USER_ACCOUNTS')));
        return "";
    }
    
    print $q->Tr(
        $q->td({-colspan => 2},
            $q->p($self->localise('SHOW_FETCHMAIL_USERS')))),"\n";

    print "<tr><td colspan=\"2\">";
    print $q->start_table({-class => 'sme-border'}), "\n        ";
    print $q->Tr(
        esmith::cgi::genSmallCell($q, $self->localise('ACCOUNT'), "header"),
        esmith::cgi::genSmallCell($q, $self->localise('USER_NAME'), "header",), 
        esmith::cgi::genSmallCell($q, $self->localise('NB_EXT_BOX'), "header",), 
        esmith::cgi::genSmallCell($q, $self->localise('GHOST_ACCOUNT'), "header",),
        esmith::cgi::genSmallCell($q, $self->localise('DEBUG_MAILBOX'), "header",),
        esmith::cgi::genSmallCell($q, $self->localise('ACTION'), "header", 2), "\n",
    );
    foreach my $u (@users) {
        my $user     = $u->key();
        my $name     = $u->prop('FirstName') . " " . $u->prop('LastName');
        my $NumBox   = $u->prop('FM-NumBox') ;
        my $ghostout = '' ; my $Debugout = '' ;
        my $keepopt = '' ; my $transname = '' ;
        my $outing   = $NumBox ;
        if ( defined $NumBox && $NumBox > 0 ) {
            $ghostout  = $u->prop('FM-Ghost') ;
            $Debugout  = $u->prop('FM-DebugOption') ;
            $keepopt   = "KEEP_" . $u->prop('FM-KeepOption') ;
            $transname = $u->prop('FM-TransName') ;
        } else {
            $NumBox = 0 ;
        }
        # Select choice :
        # if NumBox > 0 whe need a modify and a remove choice
        # else we need a create choice
        my $link1 =$q->a({href => $q->url(-absolute => 1)
                . "?page=0&Next=SetGeneral&user=$user&name=$name&"
                . "NumBox=$NumBox&ghost=$ghostout&debug=$Debugout&"
                . "mail-keep=$keepopt&forward-mail=$transname"},
                $self->localise('MODIFY')) ;
        my $link2 = $q->a({href => $q->url(-absolute => 1)
                . "?page=4&Next=First&user=$user"},
                $self->localise('REMOVE')) ;
        if ( $NumBox == 0 ) { 
            $link1 =$q->a({href => $q->url(-absolute => 1)
                . "?page=0&Next=SetGeneral&user=$user&name=$name&"
                . "NumBox=$NumBox&ghost=$ghostout&debug=$Debugout&"
                . "mail-keep=$keepopt&forward-mail=$transname"},
                $self->localise('CREATE')) ;
            $link2 = "&nbsp;" ;
        }

        print $q->Tr(
            esmith::cgi::genSmallCell($q, $user),
            esmith::cgi::genSmallCell($q, $name),
            esmith::cgi::genSmallCell($q, $NumBox),
            esmith::cgi::genSmallCell($q, $self->localise($ghostout) || '&nbsp;'),
            esmith::cgi::genSmallCell($q, $self->localise($Debugout) || '&nbsp;'),
            esmith::cgi::genSmallCell($q, $link1),
            esmith::cgi::genSmallCell($q, $link2),
            "\n",
        );
    }
    print $q->end_table,"\n";
    print '</td></tr>';

    $self->debug_msg("show_fetchmail_users ends.") ;
    return undef;
 
}

=head2 show_accounts

This method displays the list of externals accounts 
already set for a given user.

=cut

sub show_accounts {
    my $self = shift ;
    my $q = $self->{cgi} ;
    $self->debug_msg("show_accounts begins.");

    # retrieve users Data...
    my $user = $q->param('user');
    $self->debug_msg("\$user = $user.");
    my $name = $q->param('name');
    $self->debug_msg("\$name = $name.");
    my $u = $accountdb->get($user);

    # Two cases : The account is already under modification.
    # in this case, $q->prop('DataHide') is set.
    # otherwise, we read data in the database, and set
    # $q->prop('DataHide')
    my $rec = get_temp_rec($self) ;
    my $DataHide = $rec->prop('DataHide') || '' ;
    if ( $DataHide eq 'empty' ) {
        $DataHide = '' ;
    } elsif ( $DataHide ne '' ) {
        $self->debug_msg("DataHide vas not empty : \$DataHide = $DataHide.");
    } else {
        $DataHide = $u->prop('FM-Accounts') || '' ;
        $self->debug_msg("DataHide vas empty : \$DataHide = $DataHide.");
        $rec->set_prop('DataHide', $DataHide) ;
    }
    if ( defined $DataHide && $DataHide ne '' ) {
        print $q->Tr(
            $q->td({-colspan => 2},
                $q->p($self->localise('SHOW_FETCHMAIL_ACCOUNTS')))),"\n";

        print "<tr><td colspan=\"2\">";
        print $q->start_table({-class => 'sme-border'}), "\n        ";
        print $q->Tr(
            esmith::cgi::genSmallCell($q, $self->localise('MAIL_SERVER'), "header"),
            esmith::cgi::genSmallCell($q, $self->localise('MAIL_TYPE'), "header",), 
            esmith::cgi::genSmallCell($q, $self->localise('MAIL_ACCOUNT'), "header",), 
            esmith::cgi::genSmallCell($q, $self->localise('MAIL_PASSWORD'), "header",),
            esmith::cgi::genSmallCell($q, $self->localise('ACTION'), "header", 2), "\n",
        );
        my @MailDatas = split ( RS, $DataHide ) ;
        foreach my $data ( @MailDatas ) {
            my @Rec = split ( FS, $data ) ;
            my $nlink1 = "<input type=\"submit\" name=\"MOD_" . $data . "\" value=\""
           . $self->localise('MODIFY' ) . "\">" ;
            my $nlink2 = "<input type=\"submit\" name=\"DEL_" . $data . "\" value=\""
           . $self->localise('REMOVE' ) . "\">" ;

            print $q->Tr(
                esmith::cgi::genSmallCell($q, $Rec[0]),
                esmith::cgi::genSmallCell($q, $Rec[1]),
                esmith::cgi::genSmallCell($q, CGI::escapeHTML( pack( "H*", $Rec[2] ))),
                esmith::cgi::genSmallCell($q, CGI::escapeHTML( pack( "H*", $Rec[3] ))),
                esmith::cgi::genSmallCell($q, $nlink1),
                esmith::cgi::genSmallCell($q, $nlink2),
                "\n",
            );
        }
    }
    print $q->end_table,"\n";
        print $q->table({-width => '100%'}, $q->Tr($q->th({-class => 'sme-layout'},
                    $q->submit( -name => 'previous',
                        -value => $self->localise('PREVIOUS')),
                    '&nbsp;',
                    $q->submit( -name => 'cancel',
                        -value => $self->localise('CANCEL')),
                    '&nbsp;',
                    $q->submit( -name => 'validate',
                        -value => $self->localise('VALIDATE')))));
    print '</td></tr>';

    $self->debug_msg("show_accounts ends.");
    return undef;

} 
=head2 validate_mail

This method try to check if a E-Mail address is valid

=cut

sub validate_mail {
    my $self = shift ;
    my $mail = $self->{cgi}->param('forward-mail') ;
    # starting with version 1.3.4-01, it's allowed to have more than one
    # external mail redirection. Simply give all mail addresses, separated by ','
    $mail =~ s/\s//g ;
    my $mailpattern = '(\w+[\-\.])*\w+\@([a-z0-9\-]+\.){1,4}[a-z]{2,7}' ;
    if ( ! ( $mail =~ /^$mailpattern(:$mailpattern)*$/i ) && $mail ne '' ) {
    # A valid e-mail address contains lettters, digit and underscores, and optionally 
    # '-' and or '.' as field separator, then one @ then a valid domain name :
    # a domain name is one to four word + dot, then a word between 2 and 5 characters
        $self->debug_msg("the e-mail add $mail don't seems to be a valid address.");
        return $self->localise('ERR_BADMAIL');
    }
    else
    { return 'OK'; }
}

=head2 validate_account_data

This method try to validate a server name,
an account name and/or an account password.

=cut

sub validate_account_data {
    my $self = shift ;
    # validator send first the value, and then the options(s)
    shift ;
    my $Tst  = shift ;
    $self->debug_msg("validate_account_data begins.");
    $self->debug_msg("\$Tst = $Tst.");
    my $Flag = 1 ;
    my $q = $self->{cgi} ;
    my $user = $q->param('user') ;
    my $server = '' ; my $type = 'IMAP' ; my $account = '' ; my $password = '' ;   
    $server   = $q->param('mail-server')   if ( defined $q->param('mail-server') ) ;
    $type     = $q->param('mail-type')     if ( defined $q->param('mail-type') ) ;
    $account  = $q->param('mail-account')  if ( defined $q->param('mail-account') ) ;
    $password = $q->param('mail-password') if ( defined $q->param('mail-password') ) ;
    $self->debug_msg("\$server   = $server.");
    $self->debug_msg("\$account  = $account.");
    $self->debug_msg("\$password = $password.");
    # if the three fields are blank, it's OK
    if ( ( $server . $account . $password ) ne '' ) { 
        if ( $Tst eq 'Server' ) { 
            $self->debug_msg("'Server' test begins.");
            my $IPPattern = "(([01]?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))\.){3}([01]?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))" ;
            if ( $server !~ /^([a-z0-9\-]+\.){1,4}[a-z]{2,7}$/i and $server !~ /^$IPPattern$/ ) {
                # A server name is considered as valid if if contains betweens 2 an 5
                # sections, separated by dots '.'
                # For all sections but the last, characters alloweds are letters, 
                # numbers and '-' (with no size restrictions). 
                # For the last section (or tld), only letters are allowed.
                # The length must be between 2 and 5 characters.
                # PS Add, Jan 14, 2006 : a host can also be given by it's IP address
                # The $IPPattern is from MiscPS/IP.pm . No need to add a lib for that.
                $self->debug_msg("'$server' don't seems to be a valid Internet name or IP address.");
                $Flag = 0 ;
                return $self->localise('ERR_BADSERVER');
            } 
        } 
        if ( $Tst eq 'Account' ) {
            $self->debug_msg("'Account' test begins.");
            if ( $account eq '' ) {
                $self->debug_msg("The account name $account is empty.");
                $Flag = 0 ;
                return $self->localise('ERR_FIELD_EMPTY');
            }
        }
        if ( $Tst eq 'Password' ) {
            $self->debug_msg("'Password' test begins.");
            if ( $password eq '' ) {
                $self->debug_msg("The password name $password is empty.");
                $Flag = 0 ;
                return $self->localise('ERR_FIELD_EMPTY');
            }
        }
        $self->debug_msg("After 3 tests, \$Flag = $Flag.");
    }
    $self->debug_msg("validate_account_data ends.");
    return 'OK' if ( $Flag ) ;
}

=head2 fetchmail_enable_disable

This method changes the status of Fetchmail.

=cut

sub fetchmail_enable_disable {
    my $self = shift ;
    $self->debug_msg("Start of sub 'fetchmail_enable_disable'.") ;
    my $current = $self->{cgi}->param('Current') ;
    $self->debug_msg("'fetchmail_enable_disable' : \$current = $current") ;
    my $FM = $db->get('FetchMails') 
        || ($self->error('ERR_NO_FETCHMAIL_RECORD') and return undef);
    if ( $current ) {
        $FM->set_prop("status", "disabled") ;
        $self->debug_msg("'fetchmail_enable_disable' : fetchmail disabled.") ;
    } else {
        $FM->set_prop("status", "enabled") ;
        $self->debug_msg("'fetchmail_enable_disable' : fetchmail enabled.") ;
    }
    if (system ("/sbin/e-smith/signal-event", "fetchmail-change") == 0) {
        $self->debug_msg("'fetchmail_change' : files update OK.") ;
        $self->success("SUCCESSFULLY_CHANGED_CONF");
    } else {
        $self->debug_msg("'fetchmail_change' : files update fails.") ;
        $self->error("ERROR_WHILE_CHANGING_CONF");
    }
    return undef ;
}

=head2 fetchmail_change_account

This method remove an external mail account or set
the data in the display for modification.

=cut

sub fetchmail_change_account {
    my $self = shift ;
    my $q    = $self->{cgi} ;
    my $rec  = get_temp_rec( $self ) ;

    $self->debug_msg("Start of sub 'fetchmail_change_account'.") ;
    my $ghost = $q->param('ghost') ;
    $self->debug_msg("\$ghost = $ghost") ;
    my $mailserver = $q->param('mail-server') ;
    $self->debug_msg("\$mailserver = $mailserver") ;
    my $action = $q->param('action') ;
    $self->debug_msg("\$action = $action") ;
    my $user = $q->param('user') ;
    $self->debug_msg("\$user = $user") ;
    my $data = $q->param('data') ;
    $self->debug_msg("\$data = $data") ;
    my $u = $accountdb->get($user);

    if ( $action eq 'remove' ) {
        $self->debug_msg("account to remove.") ;
        
        my @fetchdata1 = split( RS, $q->param('DataHide') ) ;
        $self->debug_msg("DataHide : " . $q->param('DataHide') ) ;
        my @fetchdata2 ;
        foreach my $t ( @fetchdata1 ) {
            push @fetchdata2, $t if ( $t ne $data ) ;
            }
        $self->debug_msg("\@fetchdata2 : " . join( "-", @fetchdata2 ) ) ;
        $q->param({-name=>'DataHide', -value=>join( RS, @fetchdata2 ) }) ;
        $self->debug_msg("DataHide : " . $q->param('DataHide') ) ;
    } else {
        my @DataTmp = split( FS, $data );
        $self->debug_msg("account to modify.") ;
        # Just store the data to change, and start the page again
        $rec->set_prop('AccountMod', $data) ;
    }
    $self->debug_msg("'fetchmail_change_account' : \$self->wherenext(\"SetAccounts\");") ;
    $self->wherenext("SetAccounts");
    # $self->debug_msg("'fetchmail_change_account' : \$self->success();") ;
    # $self->success();
    return undef ;
}

=head2 display_general

This method displays accounts value if it's
an account modification.

=cut

sub display_general {
    my $self  = shift ;
    my $Field = shift ;
    my $q     = $self->{cgi};
    my $rec   = get_temp_rec($self) ;

    $self->debug_msg("'display_general' begins.") ;
    my  $ghost     = $q->param('ghost')        || 'NO'  ;
    my  $debug     = $q->param('debug')        || 'NO'  ; 
    my  $keep      = $q->param('mail-keep')    || 'NO'  ;
    my  $forwarder = $q->param('forward-mail') || ''    ;
    $forwarder     =~ s/\s//g ;
    if ( defined $rec->prop('SetGeneral') ) {
        my @tmp    = split ( FS, $rec->prop('SetGeneral') ) ;
        $ghost     = $tmp[0] ;
        $debug     = $tmp[1] ;
        $keep      = $tmp[2] ;
        $forwarder = $tmp[3] ;
    }
    return $ghost       if ( $Field eq 'ghost' ) ;
    return $debug       if ( $Field eq 'debug' ) ;
    return $keep        if ( $Field eq 'keep' ) ;
    return $forwarder   if ( $Field eq 'forwarder' ) ;
    $self->debug_msg("'display_general' ends.") ;
}

=head2 display_account

This method displays accounts value if it's
an account modification.

=cut

sub display_account {
    my $self  = shift ;
    my $Field = shift ;
    my $q     = $self->{cgi};
    my $rec   = get_temp_rec($self) ;

    $self->debug_msg("'display_account' begins.") ;
    my $data = "" . FS . "POP3" . FS . "" . FS . "" ;
    $data = $rec->prop('AccountMod') if ( defined $rec->prop('AccountMod') ) ;
    $self->debug_msg("\$Field = $Field.") ;
    $self->debug_msg("\$data = $data.") ;
    my @Rec = split ( FS, $data ) ;
    return $Rec[0] if ( $Field eq 'Server' ) ;
    return $Rec[1] if ( $Field eq 'Type' ) ;
    return CGI::escapeHTML(pack("H*", $Rec[2] || '' )) if ( $Field eq 'Account' ) ;
    return CGI::escapeHTML(pack("H*", $Rec[3] || '' )) if ( $Field eq 'Password' ) ;

    $self->debug_msg("'display_account' ends.") ;
}

=head2 show_copy_to

This method displays a list of internals users 
to witch incoming mails should be copied.

=cut

sub show_copy_to {
    my $self = shift ;
    my $q    = $self->{cgi};
    my $rec  = get_temp_rec($self) ;

    # retrieve users Data...
    $self->debug_msg("'show_copy_to' begins.") ;
    my @users = $accountdb->get('admin');
    push @users, $accountdb->users();

    # print array header
    print "<tr><td colspan=\"2\">";
    print $q->start_table({-class => 'sme-border'}), "\n";
    print $q->Tr(
        esmith::cgi::genSmallCell($q, $self->localise('LABEL_COPY_TO'), "header"), 
        esmith::cgi::genSmallCell($q, $self->localise('LABEL_USER_ACCOUNT'), "header",),
        esmith::cgi::genSmallCell($q, $self->localise('LABEL_USER_NAME'), "header",), "\n",
    );
    
    # populate the array
    # which account is under configuration  ?
    my $account = $q->param('user') ;
    # maybe already some accounts configured ?
    my $ua = $accountdb->get($account) ;
    my $MailCopyTo = $ua->prop('FM-MailCopyTo') || '' ;
    $self->debug_msg("\$MailCopyTo from user account is : $MailCopyTo.") ;
    $MailCopyTo = $rec->prop('FM-MailCopyTo') if ( defined $rec->prop('FM-MailCopyTo') ) ;
    $self->debug_msg("\$MailCopyTo from temp database is : $MailCopyTo.") ;
    foreach my $u ( @users ) {
        my $user     = $u->key();
        my $name     = $u->prop('FirstName') . " " . $u->prop('LastName');
        my $CheckBox = "<input type=\"checkbox\" name=\"CopyTo_$user\"" ;
        $CheckBox   .= "value=\"$user\"" ;
        $CheckBox   .= " checked" if ( $MailCopyTo =~ $user ) ;
        $CheckBox   .= ">" ;
        next if ( $user eq $account ) ;
        print $q->Tr(
            esmith::cgi::genSmallCell($q, $CheckBox),
            esmith::cgi::genSmallCell($q, $user || '&nbsp;'),
            esmith::cgi::genSmallCell($q, $name || '&nbsp;'),
            "\n",
        );
    }
    print $q->end_table,"\n";
    print '</td></tr>';

    print $q->end_table,"\n";
    print $q->table({-width => '100%'}, $q->Tr($q->th({-class => 'sme-layout'},
            $q->submit( -name => 'cancel',
                        -value => $self->localise('CANCEL')),
            '&nbsp;',
            $q->submit( -name => 'next',
                        -value => $self->localise('NEXT')))));
    print '</td></tr>';

    # Everythings is fine ;-)
    $self->debug_msg("'show_copy_to' ends.") ;
    return undef ;
}

=head2 temp_store_general

This method store the 'generals attributes' for a mailbox.

=cut

sub temp_store_general {
    my $self = shift ;
    my $q    = $self->{cgi} ;
    my $rec  = get_temp_rec($self) ;
    $self->debug_msg("Start of sub 'store_general'.") ;
    # account name to work on
    my $user = $q->param('user') ;
    $self->debug_msg("\$user = $user") ;
    my $ghost     = $q->param('ghost')        || 'NO'  ;
    my $debug     = $q->param('debug')        || 'NO'  ; 
    my $keep      = $q->param('mail-keep')    || 'NO'  ;
    my $forwarder = $q->param('forward-mail') || ''    ;
    $forwarder    =~ s/\s//g ;
    $keep    =~ s/^KEEP_(.*)$/$1/ ;
    $self->debug_msg("\$ghost=$ghost \$debug=$debug");
    $self->debug_msg("\$keep=$keep \$forwarder=$forwarder");
    my $SetGeneral = join ( FS, $ghost, $debug, $keep, $forwarder) ;
    $rec->set_prop( 'SetGeneral', $SetGeneral ) ;
    # Did not find a wyse mode to scan only the checkboxes
    # So I scan all params, filtering on the name sequence, who needs
    # to begin by 'CopyTo_' 
    my @CheckBoxes ;
    my @ChTest = $self->{cgi}->param() ;
    foreach my $CheckBox ( @ChTest ) {
        if ( $CheckBox =~ s/^CopyTo_(.*)$/$1/ ) { 
            $self->debug_msg("'store_general' : \$Checkbox=$CheckBox");
            push @CheckBoxes, $CheckBox ;
        }
    }
    $rec->set_prop('FM-MailCopyTo', join( ",", @CheckBoxes) ) ;
    $self->debug_msg("FM-MailCopyTo=" . join(",", @CheckBoxes) );

    if ( $q->param('cancel') ) {
        # Cancel all change and go to the first page
        $self->debug_msg("The 'Cancel' Button was selected.") ;
        my $button = 'cancel' ;
        $q->delete($button) ;
        $rec->delete ;
        $self->debug_msg("\$self->wherenext(\"First\");") ;
        $self->wherenext("First") ;
    }

    if ( $ghost eq 'YES' && scalar( @CheckBoxes ) == 0 && $forwarder eq '' ) {
        # we have a problem : no final recipinet designed !
        $self->debug_msg("'temp_store_general' : No final recipient defined.") ;
        $self->error("ERROR_NO_FINAL_RECIPIENT") ;
        $self->wherenext("SetGeneral") ;
    }
    return undef ;
}

=head2 fetchmail_routing

This method change the 'POP3 and IMAP4 routing' mode of Fetchmail

=cut

sub fetchmail_routing {
    my $self = shift ;
    $self->debug_msg("Start of sub 'fetchmail_routing'.") ;
    my $current = $self->{cgi}->param('CurrentPOP') ;
    $self->debug_msg("'fetchmail_routing' : \$current = $current") ;
    my $FM = $db->get('FetchMails')
        || ($self->error('ERR_NO_FETCHMAIL_RECORD') and return undef);
    if ( $current ) {
        $FM->set_prop("Routing", "NO") ;
        $self->debug_msg("'fetchmail_routing' : fetchmail disabled.") ;
    } else {
        $FM->set_prop("Routing", "YES") ;
        $self->debug_msg("'fetchmail_routing' : fetchmail enabled.") ;
    }
    if (system ("/sbin/e-smith/signal-event", "fetchmail-routing") == 0) {
        $self->success("SUCCESSFULLY_MODIFIED_ROUTING");
        $self->debug_msg("'fetchmail_routing' : masq update OK.") ;
    } else {
        $self->error("ERROR_WHILE_MODIFYING_ROUTING");
        $self->debug_msg("'fetchmail_routing' : masq update fails.") ;
    }
    return undef ;
}

=head2 fetchmail_routingSMTP

This method change the 'SMTP routing' mode of Fetchmail

=cut

sub fetchmail_routingSMTP {
    my $self = shift ;
    $self->debug_msg("Start of sub 'fetchmail_routingSMTP'.") ;
    my $current = $self->{cgi}->param('CurrentSMTP') ;
    $self->debug_msg("'fetchmail_routingSMTP' : \$current = $current") ;
    my $FM = $db->get('FetchMails')
        || ($self->error('ERR_NO_FETCHMAIL_RECORD') and return undef);
    if ( $current ) {
        $FM->set_prop("RoutingSMTP", "NO") ;
        $self->debug_msg("'fetchmail_routingSMTP' : fetchmail disabled.") ;
    } else {
        $FM->set_prop("RoutingSMTP", "YES") ;
        $self->debug_msg("'fetchmail_routingSMTP' : fetchmail enabled.") ;
    }
    if (system ("/sbin/e-smith/signal-event", "fetchmail-routing") == 0) {
        $self->success("SUCCESSFULLY_MODIFIED_ROUTINGSMTP");
        $self->debug_msg("'fetchmail_routingSMTP' : masq update OK.") ;
    } else {
        $self->error("ERROR_WHILE_MODIFYING_ROUTINGSMTP");
        $self->debug_msg("'fetchmail_routingSMTP' : masq update fails.") ;
    }
    return undef ;
}

=head2 fetchmail_SMTPProxy

This method change the state of the SME SMTP Proxy

=cut

sub fetchmail_SMTPProxy {
    my $self = shift ;
    $self->debug_msg("Start of sub 'fetchmail_SMTPProxy'.") ;
    my $current = $self->{cgi}->param('CurrentSMTPProxy') ;
    $self->debug_msg("'fetchmail_SMTPProxy' : \$current = $current") ;
    # we need also information about smtpfront-qmail
    # PS 2005/08/02 -> 1.3.4-05
    # SME7 no longer use smtpfront-qmail, but use smtpd instead
    my $SysConfig = $db->get('sysconfig') ;
    my $SMEVersion = ( $SysConfig->prop('ReleaseVersion') || 0 ) ;
    $SMEVersion =~ s/^(\d+)\..*$/$1/ ;
    my $MailSystem = 'smtpfront-qmail' ;
    $MailSystem = 'smtpd' if ( $SMEVersion > 6 ) ;
    $self->debug_msg("'fetchmail_SMTPProxy' : Major Version = $SMEVersion - Mailsystem = $MailSystem.") ;
    my $SmtpProxy = $db->get($MailSystem) 
        or ($self->error('ERR_NO_SMTPFRONT-QMAIL_RECORD') and return undef) ;
    if ( $current ) {
        $SmtpProxy->set_prop("Proxy", "disabled") ;
        $self->debug_msg("'fetchmail_SMTPProxy' : SMTP Proxy disabled.") ;
    } else {
        $SmtpProxy->set_prop("Proxy", "enabled") ;
        $self->debug_msg("'fetchmail_SMTPProxy' : SMTP Proxy enabled.") ;
    }
    if (system ("/sbin/e-smith/signal-event", "remoteaccess-update") == 0) {
        $self->success("SUCCESSFULLY_MODIFIED_SMTPPROXY");
        $self->debug_msg("'fetchmail_SMTPProxy' : $MailSystem update OK.") ;
    } else {
        $self->error("ERROR_WHILE_MODIFYING_SMTPPROXY");
        $self->debug_msg("'fetchmail_SMTPProxy' : $MailSystem update fails.") ;
    }
    return undef ;
}

=head2 fetchmail_routing

This method change the 'NNTP routing' mode of Fetchmail

=cut

sub fetchmail_routingNNTP {
    my $self = shift ;
    $self->debug_msg("Start of sub 'fetchmail_routingNNTP'.") ;
    my $current = $self->{cgi}->param('CurrentNNTP') ;
    $self->debug_msg("'fetchmail_routingNNTP' : \$current = $current") ;
    my $FM = $db->get('FetchMails')
        || ($self->error('ERR_NO_FETCHMAIL_RECORD') and return undef);
    if ( $current ) {
        $FM->set_prop("RoutingNNTP", "NO") ;
        $self->debug_msg("'fetchmail_routingNNTP' : fetchmail disabled.") ;
    } else {
        $FM->set_prop("RoutingNNTP", "YES") ;
        $self->debug_msg("'fetchmail_routingNNTP' : fetchmail enabled.") ;
    }
    if (system ("/sbin/e-smith/signal-event", "fetchmail-routing") == 0) {
        $self->success("SUCCESSFULLY_MODIFIED_ROUTINGNNTP");
        $self->debug_msg("'fetchmail_routingNNTP' : masq update OK.") ;
    } else {
        $self->error("ERROR_WHILE_MODIFYING_ROUTINGNNTP");
        $self->debug_msg("'fetchmail_routingNNTP' : masq update fails.") ;
    }
    return undef ;
}

=head2 validate_change

This method is launched by any button on the second page.
Upon button choice, many possibility :
Go one page back, Cancel any change and go back to
The first page, Validate Change and go back on the first
page with a success message, valid_account validate an
account and stay on the same page.

=cut

sub validate_change {
    my $self = shift ;
    my $q    = $self->{cgi} ;
    my $rec  = get_temp_rec($self) ;

    $self->debug_msg("Start of 'validate_change'.") ;
    # We have to gather a lot of informations...
    my $user   = $q->param('user') ;
    my $name   = $q->param('name') ;
    my $server   = $q->param('mail-server')   || ''     ;
    my $type     = $q->param('mail-type')     || 'POP3' ;
    my $account  = $q->param('mail-account')  || ''     ;
    my $password = $q->param('mail-password') || ''     ;
    # it's better to store account and password in 
    # hex form (to avoid clash with some special characters)
    $account  = unpack( "H*", CGI::unescapeHTML( $account  ) ) ;
    $password = unpack( "H*", CGI::unescapeHTML( $password ) ) ;
    # We need to clean-up the destination cases
    $q->delete('mail-server') ;
    $q->delete('mail-type') ;
    $q->delete('mail-account') ;
    $q->delete('mail-password') ;

    $self->debug_msg("\$user     = $user.");
    $self->debug_msg("\$name     = $name.");
    $self->debug_msg("\$server   = $server.");
    $self->debug_msg("\$type     = $type.");
    $self->debug_msg("\$account  = $account.");
    $self->debug_msg("\$password = $password.");
    
    my @accounts ; 
    my $DataHide = $rec->prop('DataHide') || '' ;
    if ( $DataHide ne '' ) {
        @accounts   = split ( RS, $DataHide ) ;
    }
    $self->debug_msg("\@accounts = " . join ( "-", @accounts ) . "." );
    my %accountsort ;
    foreach my $line ( @ accounts ) {
        $accountsort{ $line } = $line if ( $line ne 'empty' ) ;
    }
    my $AccountMod = $rec->prop('AccountMod') || '' ;
    $self->debug_msg("\$AccountMod  = $AccountMod.");
    if ( $AccountMod ne '' ) {
        delete $accountsort{ $AccountMod } if ( $server ne '' ) ;
        $rec->delete_prop('AccountMod') ;
    }
    # if $server is not empty, we need to store the 4 values in DataHide
    # FormMagik has already checked if the data seems valids.
    if ( $server ne '' ) {
        my $data = join( FS, $server, $type, $account, $password ) ; 
        $accountsort{ $data } = $data ;
    }
    # Special case : We already check if a 'REMOVE' button was depressed
    my @ChTest = $self->{cgi}->param() ;
    my $deleteButton = 0 ;
    my $button = '';
    foreach my $Button ( @ChTest ) {
        if ( $Button =~ s/^DEL_(.*)$/$1/ ) { 
            $self->debug_msg("Button DEL_$Button");
            if ( $q->param('DEL_' . $Button) ) {
                $self->debug_msg("The 'DEL_$Button' was selected.") ;
                delete $accountsort{ $Button } ;
                $button = 'DEL_' . $Button ;
                $q->delete($button) ;
                $deleteButton = 1 ;
            }
        }
    }
    
    # it's time to update DataHide
    @accounts = () ;
    foreach my $line ( sort keys %accountsort ) {
        push @accounts, $line ;
    }
    $DataHide = 'empty' ;
    $DataHide = join( RS, @accounts ) if ( $#accounts > -1 ) ;
    $self->debug_msg("\$DataHide is updated to $DataHide") ;
    $rec->set_prop('DataHide', $DataHide) ;

    # Now, we vant to know witch button was depressed.
    # If the button is a 'REMOVE' Button, we already know
    if ( $deleteButton ) {
        $self->debug_msg("'validate_change' : \$self->wherenext(\"SetAccounts\");") ;
        $self->wherenext("SetAccounts");
    }
    if ( $q->param('previous') ) {
        # go to previous page...
        $self->debug_msg("The 'Previous' Button was selected.") ;
        $button = 'previous' ;
        $q->delete($button) ;
        $self->debug_msg("'validate_change' : \$self->wherenext(\"SetGeneral\");") ;
        $self->wherenext("SetGeneral");
    }
    if ( $q->param('cancel') ) {
        # Cancel all change and go to the first page
        $self->debug_msg("The 'Cancel' Button was selected.") ;
        $button = 'cancel' ;
        $q->delete($button) ;
        $rec->delete ;
        $self->debug_msg("'validate_change' : \$self->wherenext(\"First\");") ;
        $self->wherenext("First") ;
    }
    if ( $q->param('validate') ) {
        # (Try to) validate all changes and go to the first page
        $self->debug_msg("The 'Validate' Button was selected.") ;
        $button = 'validate' ;
        $q->delete($button) ;
        my $FetchMailAccounts = $rec->prop('DataHide') ;
        $FetchMailAccounts = '' if ( $FetchMailAccounts eq 'empty' ) ;
        my @tmp = split( RS, $FetchMailAccounts ) ;
        my $NumBox = $#tmp + 1 ;
        my @SetGeneral = split ( FS, $rec->prop('SetGeneral') ) ;
        my $MailCopyTo = $rec->prop('FM-MailCopyTo') ;
        $self->debug_msg("Ready to update the user account (ta-daa !)");
        $self->debug_msg("\$FetchMailAccounts = $FetchMailAccounts");
        $self->debug_msg("\@SetGeneral = " . join( "-", @SetGeneral ) );
        $self->debug_msg("\$MailCopyTo = $MailCopyTo");
        my $user = $q->param('user');
        $self->debug_msg("\$user = $user.");
        my $u = $accountdb->get($user);
        if ( $NumBox > 0 ) {
            $u->set_prop('FM-NumBox',         $NumBox ) ;
            $u->set_prop('FM-Accounts',       $FetchMailAccounts ) ;
            $u->set_prop('FM-MailCopyTo',     $MailCopyTo ) ;
            $u->set_prop('FM-Ghost',          $SetGeneral[ 0 ] ) ;
            $u->set_prop('FM-DebugOption',    $SetGeneral[ 1 ] ) ;
            $u->set_prop('FM-KeepOption',     $SetGeneral[ 2 ] ) ;
            $u->set_prop('FM-TransName',      $SetGeneral[ 3 ] ) ;
        } else { # no mailboxes, remove fetchmails datas
            $u->delete_prop('FM-NumBox')      if (defined $u->prop('FM-NumBox') ) ;
            $u->delete_prop('FM-Accounts')    if (defined $u->prop('FM-Accounts') ) ;
            $u->delete_prop('FM-MailCopyTo')  if (defined $u->prop('FM-MailCopyTo') ) ;
            $u->delete_prop('FM-Ghost')       if (defined $u->prop('FM-Ghost') ) ;
            $u->delete_prop('FM-DebugOption') if (defined $u->prop('FM-DebugOption') ) ;
            $u->delete_prop('FM-KeepOption')  if (defined $u->prop('FM-KeepOption') ) ;
            $u->delete_prop('FM-TransName')   if (defined $u->prop('FM-TransName') ) ;
        }
        $rec->delete ;
        # temp databas cleanup, if needed
        my $removed = temp_database_cleanup($self) ;
        # We now must regenerate all configs files...
        if (system ("/sbin/e-smith/signal-event", "fetchmail-change") == 0) {
            $self->debug_msg("'fetchmail_change' : files update OK.") ;
            $self->success("SUCCESSFULLY_CHANGED_CONF");
        } else {
            $self->debug_msg("'fetchmail_change' : files update fails.") ;
            $self->error("ERROR_WHILE_CHANGING_CONF");
        }
    }
    if ( $q->param('valid_account') ) {
        # Temp Store Account set/update, goto same page.
        $self->debug_msg("The 'Valid_Account' Button was selected.") ;
        $button = 'valid_account' ;
        $q->delete($button) ;
        $self->debug_msg("'validate_change' : \$self->wherenext(\"SetAccounts\");") ;
        $self->wherenext("SetAccounts");
    }
    # Did not find a wyse mode to scan only the Buttons
    # So I scan all params, filtering on the name sequence, who needs
    # to begin by 'MOD_'
    # my @ChTest = $self->{cgi}->param() ;
    foreach my $Button ( @ChTest ) {
        if ( $Button =~ s/^MOD_(.*)$/$1/ ) { 
            $self->debug_msg("Button $Button");
            if ( $q->param('MOD_' . $Button) ) {
                $self->debug_msg("The '$Button' was selected.") ;
                $rec->set_prop('AccountMod', $Button) ;
                $self->debug_msg("'AccountMod' = " . $rec->prop('AccountMod') ) ;
                $button = 'MOD_' . $Button ;
                $q->delete($button) ;
                $self->debug_msg("'validate_change' : \$self->wherenext(\"SetAccounts\");") ;
                $self->wherenext("SetAccounts");
            }
        }
    }
    
    # End of method
    $self->debug_msg("End of 'validate_change'.") ;
}

=head2 remove_fetchmail_user

This method removes the fetchmails parameters for a user

=cut

sub remove_fetchmail_user {
    my $self = shift ;
    my $q    = $self->{cgi} ;

    $self->debug_msg("Start of sub 'remove_fetchmail_user'.") ;
    my $user = $q->param('user') ;
    $self->debug_msg("\$user = $user") ;
    my $u=$accountdb->get($user) ;
    $u->delete_prop('FM-NumBox')      if (defined $u->prop('FM-NumBox') ) ;
    $u->delete_prop('FM-Accounts')    if (defined $u->prop('FM-Accounts') ) ;
    $u->delete_prop('FM-MailCopyTo')  if (defined $u->prop('FM-MailCopyTo') ) ;
    $u->delete_prop('FM-Ghost')       if (defined $u->prop('FM-Ghost') ) ;
    $u->delete_prop('FM-DebugOption') if (defined $u->prop('FM-DebugOption') ) ;
    $u->delete_prop('FM-KeepOption')  if (defined $u->prop('FM-KeepOption') ) ;
    $u->delete_prop('FM-TransName')   if (defined $u->prop('FM-TransName') ) ;
    # We now must regenerate all configs files...
    if (system ("/sbin/e-smith/signal-event", "fetchmail-change") == 0) {
        $self->debug_msg("'fetchmail_change' : files update OK.") ;
        $self->success("SUCCESSFULLY_CHANGED_CONF");
    } else {
        $self->debug_msg("'fetchmail_change' : files update fails.") ;
        $self->error("ERROR_WHILE_CHANGING_CONF");
    }
    return undef ;
}

=head2 show_fetchmail_status

This method show the current status of fetchmail (enabled or disabled)
and allow the status change

=cut

sub show_schedule_infos {
    my $self = shift ;
    my $q = $self->{cgi} ;
    # Create a box with some explanations ...
    print "<center><table width=95% border=\"2\" frame=box rules=none cellpadding=\"5\"5>\n" ;
    print "<tr><td>" . $self->localise('SHOW_SCHEDULE_INFOS') . "</td></tr>\n" ;
    print "</table></center>\n" ;
    print "<br>\n" ;

    return undef ;
}

1;
