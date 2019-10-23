#!/usr/bin/python3
# https://bugzilla.altlinux.org/show_bug.cgi?id=33532
#!/usr/bin/env -S python3 -u
# -*- coding: utf-8 -*-
#
# A simple message-sending script

# TODO: When error: No handlers could be found for logger "pyxmpp.Client"

import os, sys

# python-module-pyxmpp
from pyxmpp2.jid import JID
from pyxmpp2.jabber.simple import send_message

# set in korinf config file
jid = os.environ['KORINFERJID']
password = os.environ['KORINFERJIDPASSWD']

if len(sys.argv)!=4:
    print("Usage:")
    print("\t%s recipient_jid subject body" % (sys.argv[0],))
    print("example:")
    print("\t%s test1@localhost Test 'this is test'" % (sys.argv[0],))
    sys.exit(1)

recpt,subject,body=sys.argv[1:]

jid = JID(jid)
if not jid.resource:
    jid = JID(jid.node,jid.domain,"korinf")

recpt = JID(recpt)
send_message(jid,password,recpt,body,subject)
