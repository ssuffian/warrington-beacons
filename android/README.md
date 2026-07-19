# Android Trail App

## TODOs

* Test on the actual trail
* Get access to Warrington Parks Play Store account again (emailed Andy & co.)
* Deploy internal testing build to Play Store

## Overview

This app uses data files and images currently hosted at
https://lionspride.chariotsolutions.cloud/us202/

The main data file is `us202trail-v2.json` which includes
the trail geometry and landmarks

There are physical beacons installed along the trail.
They are Radius Network E4 models, that take 4 AA batteries,
and can broadcast both iBeacon (iOS) and AltBeacon (Android)
signals.  They are configured to use a UUID and Major Code
specific to the app and trail, and the Minor Code for each
beacon identifies which Landmark it is for.  The data file
above includes those codes.

In the original Lions Pride Park the beacons could be fairly
close together and it was common to read multiple ones and
need to distinguish which one you're actually close to.
On the US202 to Bradford Dam trail the beacons are farther apart.

## Cloud Resources

The original AWS account with the S3 bucket
`lions-pride-park-configuration` was owned by email
`info@lionspridepark.org` but that domain has been abandoned
and the email address is no longer accessible, making 2FA login
using an emailed code impossible.  Thus the files for the original
Lions Pride app and iOS US202-to-Bradford-Dam app were at:

https://lions-pride-park-configuration.s3.us-east-2.amazonaws.com/

with data files:
* https://lions-pride-park-configuration.s3.us-east-2.amazonaws.com/lionsPrideData.json
* https://lions-pride-park-configuration.s3.us-east-2.amazonaws.com/202ConnectorData.json

However, without further access to that account, the current files
used for Android are in Chariot sandbox 897893808641 in S3 bucket
`lionspride.chariotsolutions.cloud`.  That was originally used to
host a Web app for generating code for park apps like this, but that
effort was also abandoned.  While the app code is still there, it's
not being used.  There's a subdirectory `us202` to hold the current
files for this app (data file and images).  Ultimately this should
all be moved to an AWS account owned by Warrington Township.

https://lionspride.chariotsolutions.cloud/us202/us202trail-v2.json

There is also a Google Cloud project for the Google Maps API Key,
which is called "Lions Pride Android Maps" and owned by Russ Diamond
(the main Lions Club contact), with his credit card(s) on file.
Aaron Mulder has access to add new API Key configuration (e.g. to add
a new app ID/fingerprint if needed).

## App Store Accounts

The iOS App Store account is "Warrington Township" and I'm not sure
who owns it.  Aaron Mulder has access to deploy new builds.

The Android Play Store account is "Warrington Parks" and owned by Andy Oles
at the township.  He granted Aaron Mulder temporary access which
has since expired.

## Beacon Programming

You can Google for the RadBeacon E4 user manual, currently:
https://support.radiusnetworks.com/hc/en-us/articles/360021233051-RadBeacon-E4-User-Guide

First hold the button in the middle of the central grey stripe for 10s+
and then release and a blue light should start flashing, indicating
it's in programming mode.

Use the RadBeacon E app (I use iOS).  Import the Lions Pride key
from `lions-pride-beacon-key.r12` (ask Aaron Mulder for this).

The main screen of the app should scan for beacons in programming mode.
Select the one to work with.  Change the key to the Lions Pride key using
the control at the top of the screen (not the drop-down in the middle)
and save.

Then select slot 1 and set it to iBeacon and put in the UUID and
Major code for the trail and the Minor code corresponding to which
Landmark it should be.  Save and select slot 2 and set it for
AltBeacon and configure it the same.  Save and set the name of the
beacon to indicate the trail and landmark and save.

Current values:
* UUID: 035a0617-0875-4cc7-a29c-be0caa8f557c
* Major code: 17 (Lions Pride) 20 (US202 to Bradford Dam)
* Minor code: see IDs in `landmark` array in the corresponding data file
