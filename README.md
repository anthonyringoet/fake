# Fake

A native macOS menu bar app for generating plausible Belgian test values.

- **Rijksregisternummer:** a valid birth date, male/female sequence parity, and the correct MOD 97 checksum (including the 2000+ rule). Shows the encoded date and sex.
- **Belgian IBAN:** 16 characters, a valid domestic account checksum, and the international MOD 97 checksum.

Values are synthesized locally, without looking up people or bank accounts. **A valid format cannot guarantee a number is unassigned.** Use these values only as test data. The IBAN generator uses bank prefix `539` from SWIFT's Belgian example with a random seven-digit account body; it excludes the published example account.

## Development

Requires macOS 14+ and Swift 6+ (Xcode or Command Line Tools). No dependencies.

```sh
./scripts/test.sh
```

Tests include official reference examples, century and leap-day cases, malformed inputs, the domestic zero-remainder case, and 10,000 generated pairs checked with independent arithmetic.

## Format references

- [IBZ: IT 000, Rijksregisternummer](https://www.ibz.rrn.fgov.be/sites/default/files/documents/nl/rijksregister/onderrichtingen/IT-lijst/IT000_Rijksregisternummer.pdf): birth date + series (001–997 odd for male; 002–998 even for female) + `97 − (body mod 97)`. Prefix the checksum body with `2` for births from 2000.
- [SWIFT IBAN Registry](https://www.swift.com/fr/swift-resource/9606/download): Belgium `BE` + two check digits + 12-digit BBAN; printed in groups of four.
- [Febelfin: Belgian domestic checksum and planned 2029 bank-code change](https://febelfin.be/en/themes/digitalization-innovation/digital-payments-online-banking-for-enterprises/the-belgian-banking-sector-will-migrate-to-alphanumeric-bank-identification-codes-in-2029): the first ten BBAN digits modulo 97, replacing zero with 97. Fake generates the current numeric format.
- [Febelfin: IBAN calculation](https://febelfin.be/media/pages/publicaties/2023/febelfin-standaarden-voor-afstandsbankieren/cc812e7fba-1694763196/febelfin-standard-credit-transfer-xml-2023-v1.0-en_1.pdf): move the country code and check digits to the end, convert letters to numbers, and require remainder 1 modulo 97.

This generator handles complete Gregorian dates in 1900–2099. It does not generate BIS numbers or registry numbers with unknown birth dates.
