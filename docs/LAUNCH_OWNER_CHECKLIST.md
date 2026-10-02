# Launch Owner Checklist

This is the manual owner-review companion to `PRODUCTION_LAUNCH_WORKPLAN.md`.
It records checks that automation cannot establish. Mark each item only after
the stated evidence has been reviewed; an unchecked item is not a release
claim.

## L1-L2: Image Reliability And Cache

- [ ] On iOS, verify a first Quiz image fetch and a warm cache hit on a real
  network.
- [ ] On Android, verify the same cold and warm image behavior.
- [ ] Review any persistent source-host rate limits or image failures rather
  than treating retry behavior as a fix.
- [ ] Confirm clearing the operating-system cache produces a safe refetch.

## L3: Owned Image Delivery Decision

- [ ] Approve the AWS account, region, forecast, and pay-as-you-go ownership
  decision before any infrastructure is applied.
- [ ] Review image provenance, license, checksum, dimensions, and byte limits
  for every asset proposed for publishing.
- [ ] Confirm no production URL changes until the owned HTTPS origin is live
  and independently verified.

## L4: Editorial Event Counts

- [ ] Review each below-four-event date and record a clear editorial exception
  reason in its curated day entry.
- [ ] Confirm ordinary curated dates have one featured event and at least three
  additional events.
- [ ] Confirm five or more total events are retained when they are strong and
  well sourced, with no artificial upper cap or weak padding.
- [ ] Inspect a long additional-events list in the app to confirm it scrolls
  without truncation.

## L5: Review Ledger And Coverage Reporting

- [ ] Review the generated content-coverage report and its source/link status.
- [ ] Sign off on editorial exceptions and unresolved source-quality findings.

## L6: Daily Event Coverage

- [ ] Review each content batch for source support, date accuracy, concise
  copy, featured notification text, and geographic/subject variety.
- [ ] Confirm the next release window meets the approved event-count policy.

## L7: Resilience And Release Readiness

- [ ] Complete native accessibility checks, including large text and screen
  reader paths, on supported devices.
- [ ] Confirm notification, backend outage, image outage, and local-cache
  recovery behavior in the release environment.

## L8: Launch Approval

- [ ] Approve production infrastructure, credentials handling, monitoring, and
  cost ownership through the separately reviewed deployment process.
- [ ] Verify iOS and Android release builds, store requirements, privacy
  disclosures, and Firebase/APNs configuration.
- [ ] Record final go/no-go approval with the outstanding risks, if any.

## Post-Audit Product Coherence

- [ ] Verify Daily-5 contains one approved featured-event-linked question when
  eligible content exists, and safely falls back when it does not.
- [ ] Verify linked generation remains deterministic with stable 5/10/20
  prefixes and does not rewrite completed assignments.
- [ ] Review the seven-day Recent experience and confirm it does not become an
  arbitrary archive or replace official results.
- [ ] Confirm Event Detail, Daily, Results, and Review form a clear learning loop.

## Post-Audit Content Quality

- [ ] Review pack-level correct-answer positions and confirm list order has no
  semantic meaning.
- [ ] Review distractors for category, specificity, ambiguity, prompt leakage,
  and obviously implausible choices.
- [ ] Review featured-image coverage and an explicit image-rights outcome for
  every date in the release window.
- [ ] Compare draft/source-verified, approved canonical, and imported database
  counts and fingerprints before release.

## Post-Audit Retention And Observability

- [ ] Verify notification permission is never shown over a blank launch view.
- [ ] Separately record debug local, iOS simulator-injected, Android FCM, and
  physical iOS APNs results without treating one as proof of another.
- [ ] Review the widget's current/stale/empty states and Event Detail deep link.
- [ ] Review event/result share cards for attribution and image reuse rights.
- [ ] Approve the privacy disclosure and minimal analytics/crash event set before
  enabling production telemetry. Review `TELEMETRY.md` and verify native
  defaults remain off in builds without the explicit release flag.
