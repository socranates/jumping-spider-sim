# Current notebook content checkpoint

2026-10-23. This is a bounded content/source reconciliation for the private
273-source candidate, SHA256
`bf77f6c885237f14fd274cf4c419300a88507d876c3cf780824b18d9ca2577d9`.
The [source inventory](integrated-source/inventory.json) binds NotebookPages,
NotebookWatch, notebook presentation and the rest of the actual staged game.
No notebook text, generator, trigger or creature behavior changed here.

The generated NotebookPages has **50** pages, with unique IDs and one title,
trigger, text, game note and nonempty source list per page. Static literal
inspection found the longest main `text` is **515 characters/UTF-8 bytes**, below
the requested 520 bound. The longest title is 38. The longest separate `game`
note is 1066; the 520 body-text bound must not be reported as a bound on every
field or as proof that every device lays out a page comfortably.

The current complete CLI run's notebook suite reports 1517 passed / 0 failed.
That suite checks notebook data, reference compatibility, control wording and
client behavior within the CLI shim. Its result does not establish biological
accuracy, source access, native line wrapping or phone/controller comfort.

The [source bibliography](../NOTEBOOK_SOURCES.md) retains explicit historical
access limits and now indexes the luna entry. On2026-10-23 the IDNR species
account, UF/IFAS profile and primary study abstract at the author's university
were opened and checked against its four natural-history sentences. PubMed
directly exposed no abstract in this session; PMC returned a browser challenge.
No claim of reading that study's full text is made. The existing rare-build
source audit in RARE_SIGHTINGS_PLAN.md remains intact.

This is not a new sentence-by-sentence re-audit of the other 49 pages. In
particular, earlier notes about unconsulted books, abstract-only checks and
uncertain generalizations are still real limitations. Not every player-facing
UI string, creature dimension, caption, alternate input label or Reduced Motion
path has been newly reviewed on the current candidate. Those remaining scopes
stay explicit in [HEALTH-CURRENT.md](HEALTH-CURRENT.md).

## Confirmed first-page wording issue - 2026-10-24

Current `bold_jumper` text calls the conspicuous green-blue structures "fangs".
The opened [Missouri Department of Conservation species account](https://mdc.mo.gov/discover-nature/field-guide/bold-jumper)
distinguishes the iridescent basal chelicerae from the actual, less-visible
fangs. Its size section also reaches three-quarters of an inch for females
(about19mm), beyond this page's approximate6-15mm range. These are small
educational wording corrections to carry through the generator's TEXT_FIXES,
retaining the frozen original in godotText and preserving the original source
reference fixture. Proposed wording: "Adults are about 6 to 19 millimetres
long" and "shining green-blue mouthparts, called chelicerae".

This is a confirmed finding, **not an applied or published correction**.
The current font-only candidate has unchanged notebook bytes. Its visual
verification takes precedence before assembling another candidate. The source
account was opened and read; the Edwards2004 PDF search result was located but
its direct web open failed on size (14.5MB). Penn State's direct open returned
403. Neither is claimed as a full primary-paper reading. The MDC page alone
supports the distinction and the reported upper size, without borrowing its
other claims for this page or implying a full50-page audit.
