# Licence attribution contract (B-238)

Baseline: `b03233ad8ddf9e83ab5571f834aa15024ae93150` (v0.86.6).

The copyright holder requests removal of their personal name from the MIT licence.
Replace the holder with `ai-tech-lead contributors` in root LICENSE, the shared licence source
and README; preserve the year and all MIT terms. Compose all three distributions from source.
Historical records and Git history are outside this attribution edit.

The existing installer refuses any different licence, so an attribution-only edit would break
updates from released versions. Permit replacement only of the exact prior framework notice,
identified by SHA256 of UTF-8 text after the existing CRLF/CR-to-LF normalization:
`14d518c3282ed071127059700be0498802c3a89ddeca37e42150445f93a04e17`.
Current identical notices remain byte-untouched; any other notice still refuses before mutation.
Apply this recognition wherever the existing legal preflight runs, including adoption and update.
No generic copyright-line stripping, fuzzy matching, new migration command or ownership policy.

Proportionality: a root-only edit fails the existing licence-parity gate; changing shared text
alone makes existing installations un-updatable. One fixed prior-content hash in the existing
preflight is the smallest change that removes the displayed name and preserves compatibility.

Verification: extend the existing LicenseDelivery suite with prior-notice migration across all
three distributions, adoption/update, LF/CRLF, and prior notices modified in attribution or terms
refused byte-untouched. Observe migration tests red before the installer fix, then clean under
direct Windows PS7 and PS5.1 at CP437 with equal nonzero counts. Run LicenseDrift and normal release
gates/CI. A separate nonimplementer reviews the frozen implementation range and hostile cases.
Release as v0.86.7; keep the checkout fixed throughout release to avoid the known B-237 hazard.
