# Supplemental notebook claim review, 2026-10-24

Review of current NotebookPages prose, not a game-source change or a complete
50-page biology sign-off. Original bibliography/access notes remain intact.
Primary publications below were opened through the web reader; only the
sections identified were checked, not entire papers. No textbook was newly read.

| Page | Current claim checked | Evidence and decision |
|---|---|---|
| eight_eyes | Four eye pairs, narrow sharp principal view, broader secondary motion sensing | Zurek et al.2010 introduction/summary, journal PDF pp2372-73. Bruce et al.2021 introduction independently describes the four-pair system. Qualitative overview supported; no exact universal acuity or field-angle claim added. |
| motion_first | Servaea vestita with only anterior lateral eyes exposed oriented to dots and stalked flies | Zurek et al.2010 summary, eye-masking methods and Ramp trials results p2375. Supported for the named species and experimental setup, not proof that every salticid identifies prey using these eyes alone. |
| motion_first | Displacements smaller than inter-receptor spacing can elicit orienting | Zurek & Nelson2012 PubMed abstract explicitly reports this result. DOI now confirmed as10.1016/j.visres.2012.06.011; abstract-only access. Current qualitative sentence supported. |
| moving_retinas | Retinas scan and partly rotate without a body turn | Bruce et al.2021 introduction and eyetracker methods describe back-and-forth and torsional retinal motions; study is in P.audax. Supports the overview. The notebook's original Land1969 paper was not newly read; this is supplementary corroboration. |
| drinking | Liquefaction outside the spider, digestive fluids and liquid uptake | Walter et al.2017 Background paragraphs around Fig1 describe puncturing/crushing, release of digestive fluid, and pumping dissolved tissues between prey and gut. Supports this broad mechanism. The paper studies A.geniculata and S.mimosarum, not a new P.audax feeding measurement. It does not prove the game's bite timing. |
| venom | Venom precedes feeding and can immobilise prey | Walter et al.2017 abstract/Background supports the broad role, not a guaranteed speed for every prey. Front-leg grip and exact salticid capture sequence still rest on existing sources; this row is not whole-page sign-off. |
| hearing | P.audax froze at80Hz; neural responses at80-380Hz beyond3m; leg hairs are a likely sensor | Shamble et al.2016 author-hosted Cornell PDF highlights/summary and initial Results. The acoustic stimulus amplitude and experimental context matter; the prose keeps the hair mechanism tentative. Supported at that scope, not an assertion that every environmental sound is sensed. |
| green_uv | A retinal filter shifts some green-sensitive receptors toward red in Habronattus | Zurek et al.2015 author-hosted university PDF ppR403-04 and Fig1 caption. Supports the filter mechanism in the studied genus. It is not evidence that P.audax has that filter or that an RGB screen reproduces UV. DeVoe's original P.regius recordings were not newly read; that part keeps its earlier access status. |
| hungry_at_home | Daytime nests can contain hungry P.audax; hunger-regulated switches are a proposed explanation | Okuyama2011 publisher abstract supports the observation and model assumption. The current wording attributes the explanation to the author. Full paper is subscription content and was not read. Biology sentences supported at abstract scope; the game-note HUD reference is stale, as noted below. |
| retreat | Salticids use silk retreats for shelter and moulting rather than usually catching prey with silk | Jackson1979 abstract/introduction supports these functions for P.johnsoni and describes several sheltered substrates. It does not newly verify every generic tent shape or under-leaf site; original textbook source remains unconsulted. Partial claim support. |
| home_before_dark | P.johnsoni enters its nest before night and shelters through darkness/bad weather | Jackson1979 abstract/introduction and laboratory observation methods support this species-specific description. It is not an experiment on every salticid's daily schedule. |
| outgrowing_a_skin | About six days in the nest before moulting and two afterward in P.johnsoni | Jackson1979 abstract explicitly gives these approximate observed periods. This supports the named-species timing sentence, not the whole cuticle explanation or a fixed rule for every moult. |
| grown_up | Laboratory P.johnsoni male/female moult-count ranges | Jackson1978 abstract distinguishes lab males5-7/females6-8 from larger inferred field ranges. Current corrected wording matches the lab counts. The separate P.audax winter/spring sentence was not newly checked against Taylor & Peck1975. |

The study-based motion claims retain species and experiment bounds. The game's
shimmer, strips, recognition timing and tap-driven meal remain interpretations.
No new targeting, hunger, growth, feeding or biology rule follows from this review.

## Opened primary sources

- [Zurek et al.2010, journal PDF](https://journals.biologists.com/jeb/article-pdf/213/14/2372/1270717/2372.pdf): introduction/summary, eye-mask methods and Ramp trials results. Not read cover-to-cover.
- [Zurek & Nelson2012, PubMed abstract](https://pubmed.ncbi.nlm.nih.gov/22750020/): complete abstract and citation fields; full paper not read.
- [Bruce et al.2021, journal article](https://journals.biologists.com/jeb/article/224/8/jeb231035/239722/Attention-and-distraction-in-the-modular-visual): abstract, introduction and eyetracker/trial sections; not full-paper audit.
- [Walter et al.2017, BMC Genomics](https://link.springer.com/article/10.1186/s12864-017-3987-9): abstract and Background through Fig1; protein results were not audited for this notebook.
- [Shamble et al.2016, author-hosted Cornell PDF](https://cohengroup.ccmr.cornell.edu/userfiles/pubs/Shamble_CurrBio_2016.pdf): highlights, summary and initial Results. Not a full-paper reading; a Berkeley URL returned404.
- [Zurek et al.2015, author-hosted Cincinnati PDF](https://homepages.uc.edu/~morehonn/wp-content/uploads/2018/10/Zurek-DB-et-al-2015-Current-Biology.pdf): two-page article's mechanism and Figure1 caption, not all supplementary analyses.
- [Okuyama2011, publisher abstract](https://link.springer.com/article/10.1007/s00114-010-0734-3): complete abstract; subscription full text not read.
- [Jackson1979, journal PDF](https://www.americanarachnology.org/journal-joa/joa-all-articles/article/download/JoA_v7_p47.pdf/?no_cache=1): abstract, introduction and laboratory observation methods. No full-paper reading claimed.
- [Jackson1978, journal PDF](https://www.americanarachnology.org/journal-joa/joa-all-articles/article/download/JoA_v6_p1.pdf): abstract and introduction, checking lab-versus-field distinction. Not the complete29-page article or its full measurement tables.

## Confirmed game-note mismatch, pending correction

hungry_at_home says hunger appears in words under the day. In the active
Preserve, SpiderClient sets view.minimal and SpiderHud.minimalView excludes
day/dayLine and hunger words; foodText is hidden. The game now uses its
unlabelled meter and abdomen shape. The generator still carries the obsolete
sentence in ADAPTED. Correct it through that generator after the ongoing
native timing cohort, retain godotGame, and rerun the notebook checks. This is
a UI-description mismatch, not a change to starvation rules or biological text.

## Access limits retained

Direct Nature HTML/PDF opening for Nabawy2018 failed at its identity redirect.
Indexed primary text supports the distinction between sufficient muscle power
and an unmeasured actual muscle/hydraulic contribution, but is not a newly read
full paper. Direct PMC openings for Chen2013 and Walter2017 returned browser
checks. Walter's publisher article was accessible and used instead; Chen's
indexed extract was not promoted to full-text-read status. A guessed Land1969
journal path was inaccessible; no inference that the original paper was read.
Nagata's institutional PDF returned429; DeVoe's publisher DOI/PDF and PubMed
opening were unavailable. Indexed snippets were not promoted to newly read
full-text evidence. No authentication, CAPTCHA or access barrier was bypassed.

Other pages, precise animal measurements and the game-note/trigger semantics
remain separate audit work. This adds support for particular claims, not a
blanket assertion that the remaining49 pages have been verified.
