# Card Period

A native iOS app for tracking a personal spending allowance per card. Add a nickname, last four digits, limit, currency and weekly or monthly reset day. Purchases are entered manually and count in the period containing their date; history remains available after a reset. Monthly dates beyond the end of a month reset on that month's last day. Cards and purchases are stored locally on the device. Choose an accent color, and optionally show an approximate balance in another currency.

## Build and run on Linux with xtool

Install and set up [xtool](https://xtool.sh/documentation/xtool/installation-linux/), including the Darwin Swift SDK and Apple signing credentials. In this directory:

```sh
xtool dev build  # build an unsigned iOS app in xtool/CardPeriod.app
xtool dev        # build, sign, install, and launch on a connected iPhone
```

Use your own unique bundle ID in `xtool.yml` if the default cannot be registered. Device deployment requires a connected, trusted device and signing setup. If the xtool AppImage cannot mount because FUSE is unavailable, run `xtool --appimage-extract` in a temporary directory and use the resulting `squashfs-root/AppRun` in place of `xtool`.

The date and spending logic can be tested on Linux with `swift test`. There is no bank connection or automatic transaction import in this version. The app tracks a user-defined spending allowance, not a bank-reported available credit balance. Purchases and cards can be deleted; editing a card's reset schedule recalculates its current period from the stored purchase dates. Data does not sync between devices.

If provisioning reports that there are no current iOS devices on the team, register the connected device through xtool’s install flow using an unsigned IPA:

```sh
xtool dev build --ipa
xtool install --usb xtool/CardPeriod.ipa
```

The install command signs the IPA and installs it on the phone.

## Currency conversion

Conversion is optional and uses daily reference rates from [Exchange Rate API](https://www.exchangerate-api.com/). The app sends the card currency code to the provider, caches the response locally, and displays the date of the rate. Exchange rates are estimates and may differ from your bank’s rate.
