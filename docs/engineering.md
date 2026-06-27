# Engineering the Attention Dataset

## Introduction

This project began as a learning exercise.

My original objective was not to study collective attention, but to find a dataset large enough to force good engineering habits. I wanted a dataset that would punish poor modeling decisions, expose scalability challenges, and remain interesting enough to explore over several weeks.

Wikipedia pageviews quickly became the ideal candidate.

The dataset is massive, publicly available, continuously updated, and reflects the interests of millions of people across hundreds of language communities. Unlike many synthetic datasets commonly used for learning purposes, it captures real human behavior at global scale.

However, pageviews are not really a dataset in the traditional sense. They are closer to a transparency log published by Wikimedia. Each record contains only four fields:

* Timestamp
* Wiki edition
* Page title
* Number of views

For analytical purposes, this information is surprisingly limited. While it tells us that a page was viewed, it provides almost no context about what that page represents.

At the same time, the scale of the data creates immediate engineering challenges. The pageview stream is partitioned hourly, with each partition representing several gigabytes of data. Materializing long periods quickly becomes impractical.

Before designing any model, a more fundamental question emerged:

> What exactly are we trying to measure?

The answer appeared almost immediately:

> What are people paying attention to?

This question ultimately shaped the entire architecture of the project.

---

## The Problem With Pages

The first obstacle was defining the unit of attention.

At first glance, a page appears to be a reasonable unit. After all, pageviews are recorded at the page level.

However, pages are not concepts.

For example:

* Germany
* Allemagne
* Deutschland
* ألمانيا

These are distinct pages located on different language editions of Wikipedia. Yet they all represent the same underlying concept.

If the objective is to measure attention, treating these pages independently fragments the signal and prevents meaningful cross-community analysis.

The project therefore required a semantic layer capable of resolving pages into concepts.

> **A page is not an attention unit. An entity is.**

---

## Enter Wikidata

To provide semantic meaning to pageviews, I introduced Wikidata.

Unlike Wikipedia, Wikidata is a large-scale knowledge graph containing billions of entities connected through hundreds of relationship types.

Wikidata provides exactly what pageviews lack:

* Entity identities
* Cross-language mappings
* Hierarchies
* Categories
* Semantic relationships

The challenge was that Wikidata was itself massive, approaching the scale of the pageview dataset.

Fortunately, the dataset was clustered by entity identifier, which would later prove critical for graph traversal and recursive operations.

---

## First Attempt at Entity Resolution

The initial matching strategy was intentionally simple.

Pages were matched directly against entity names.

Despite the weakness of this approach, the results were surprisingly encouraging:

* Approximately 49% of pages were matched successfully.

However, further investigation revealed a significant bias.

English pages achieved matching rates above 90%.

Most other languages performed dramatically worse.

French achieved moderate results due to sharing the Latin alphabet with English, while languages such as Arabic, Chinese, and Japanese remained largely unmatched.

The matching strategy was not resolving concepts.

It was primarily resolving English concepts.

---

## Discovering Sitelinks

While exploring Wikidata, I discovered the sitelinks field.

Sitelinks connect entities to the pages representing them across Wikipedia editions.

More importantly, they do not only contain translations.

They also include related pages such as:

* Television seasons
* Lists
* Alternative representations
* Community-specific pages

This was exactly the bridge required between pageviews and entities.

Using sitelinks, I rebuilt the matching process.

The impact was immediate.

The overall matching rate increased from approximately 49% to 89%.

Even non-Latin language editions achieved strong matching performance.

For the first time, multilingual attention could be analyzed coherently.

The remaining unmatched traffic was not necessarily a modeling failure.

Some pageviews correspond to Wikimedia namespaces, emerging entities that do not yet exist in Wikidata, or pages whose sitelinks have not yet been updated.

Achieving 100% reconciliation was therefore neither realistic nor desirable. The objective was not perfect matching, but meaningful semantic coverage.

---

## The Hidden Cost of Success

The new matching strategy introduced a new problem.

Although sitelinks dramatically improved coverage, the relationship between page title, wiki edition, and entity remained imperfect.

Consider two entities sharing the same page title.

A naïve join could produce duplicate matches, causing the same pageview record to contribute views multiple times.

The consequence would be severe.

The pipeline would manufacture attention that never existed.

To prevent this, I introduced a conservation test.

The total number of views before and after entity resolution must remain identical within a tolerance of one view per million.

The purpose of the test was not to verify the correctness of the join itself.

It was to ensure that semantic enrichment never altered the underlying facts.

> Views are observations.
> Entities are interpretations.
> Interpretations must never create new observations.

---

## Changing the Grain

Entity resolution enabled a fundamental change in grain.

Originally:

**Page × Hour**

Became:

**Entity × Hour**

This transformation made the dataset significantly more informative.

Attention could now be measured at the concept level rather than at the page level.

---

## From Hourly Attention to Daily Attention

After entity resolution, the dataset was represented at the Entity × Hour grain.

While this preserved the temporal fidelity of the source data, it created a new challenge.

Wikipedia attention is extremely fragmented. Even after resolving pages into entities, the combination of thousands of entities, hundreds of language editions, and hourly observations produced a dataset whose cardinality quickly became difficult to consume.

The issue was not query execution.

The issue was analytical consumption.

Most of the questions explored by the project focused on daily attention patterns rather than hourly fluctuations:

* Attention shifts
* Trends
* Community distributions

None of these required hourly precision.

The solution was therefore to aggregate the dataset from:

**Entity × Hour**

to:

**Entity × Day**

This reduced cardinality significantly while preserving the level of detail required by the analysis.

The new daily grain also enabled the next optimization step: bucketization.

---

## Additional Dimensions

Although entity resolution established the primary analytical grain, two additional dimensions were preserved throughout the modeling process:

* Language edition
* Access medium

### Language Edition

Language metadata was generated directly from Wikimedia's `sitematrix` API.

This endpoint provides the list of Wikimedia language editions together with their associated metadata. The extracted information was used to generate a seeded language dimension containing:

* Wiki code
* Language name
* Mobile and desktop variants

Generating the dimension directly from Wikimedia ensures that the model remains aligned with the current set of supported language editions without requiring manual maintenance.

### Access Medium

Wikimedia reports mobile traffic using dedicated wiki identifiers.

Examples include:

* `en.wikipedia` → English Desktop
* `en.m.wikipedia` → English Mobile

Mobile variants were generated during the seed creation process and an `is_mobile` flag was derived to simplify downstream analysis.

This approach preserves compatibility with the raw pageview data while providing an explicit access-medium dimension.
At this stage the analytical model was functionally complete.

Entities had been resolved, attention had been aggregated at the daily level, and contextual dimensions had been introduced.

The remaining challenge was scale.

---

## Controlling Cardinality

At this stage, another challenge emerged.

Wikipedia pageviews exhibit an extremely long-tailed distribution.

Most entities receive very little attention, while a small number receive enormous volumes of traffic.

Materializing every entity proved impractical.

A reduction strategy was required.

Rather than selecting an arbitrary cutoff, I evaluated multiple thresholds and measured their impact on both entity retention and view retention.

The selected threshold was chosen as an engineering tradeoff rather than a statistical definition of relevance.

Entities are evaluated at the entity-day level. An entity preserves its identity if it exceeds the threshold on at least one day during the analysis period.

Entities that never reach that level are aggregated into bucketed categories.

This approach does not remove attention from the dataset. Total views are preserved exactly through bucketization.

The objective was to reduce model cardinality and improve Power BI VertiPaq performance while retaining entities capable of attracting meaningful attention.

In practice, the optimization substantially improved dashboard responsiveness and reduced model complexity without producing meaningful changes in the analytical outputs.

Two buckets were introduced:

* OTHER_MATCHED
* OTHER_UNMATCHED

The distinction preserves information about whether an entity was successfully resolved through the reconciliation process.

A second conservation test was introduced to validate the transformation.

Unlike entity resolution, this step requires exact preservation of views.

Entity identities may disappear.

Attention cannot.


### Design Tradeoff

The threshold is applied globally rather than per language edition.

As a result, entities that may be locally significant within smaller language communities can be aggregated into the OTHER buckets.

This tradeoff was accepted because the objective of the project is to model global attention while preserving the overwhelming majority of observed views.

---

## Structural Versus Semantic Entities

After building the first dashboards, a new issue became obvious.

Pages such as:

* Main Page
* Lists
* Navigation pages
* Wikimedia utilities

dominated many rankings.

These pages attract attention but do not represent meaningful concepts.

Removing them entirely would distort the dataset.

Instead, they needed to be identified and classified.

To accomplish this, I leveraged two Wikidata relationships:

* P31 (instance of)
* P279 (subclass of)

Starting from the Wikidata root node representing Wikimedia internal items, I recursively traversed the graph to identify all structural descendants.

Any entity belonging to this hierarchy was classified as structural.

Importantly, these entities were not removed.

They were labeled.

This distinction became one of the most important lessons of the project.

Filtering removes information.

Classification preserves information while enabling alternative interpretations.

Future analyses can always choose whether to include or exclude structural entities.

Once filtered, that choice disappears.

---
## Final Dimensional Model

The resulting analytical structure can be represented as:

> Entity × Day × Language × Medium

This structure preserves the contextual information required for cross-language and cross-platform analysis while maintaining the entity as the primary unit of attention.

Additional fields such as:

* Entity type
* Parent entity
* Structural classification
* Reconciliation status

are modeled as attributes of the entity dimension rather than independent dimensions because they are functionally determined by the entity itself.

---

## Lessons Learned

Several principles emerged during the project.

### Views Are Facts

The pageview stream records what happened.

Everything else is enrichment.

Entity resolution, classifications, communities, and metrics are interpretations built on top of those observations.

The role of the pipeline is to improve interpretation without altering the underlying facts.

### Conservation Matters

Every major transformation was accompanied by a conservation test.

The purpose was not to validate implementation details but to protect the integrity of the signal.

Attention should never be created or destroyed by the modeling process.

### Classify Before Filtering

When possible, data should be classified rather than removed.

Classification preserves flexibility for downstream consumers and avoids embedding assumptions directly into the dataset.

### The Right Grain Matters More Than The Right Tool

The most important decision of the project was not a technology choice.

It was recognizing that pages are not the correct unit of analysis.

Once the grain changed from pages to entities, the rest of the architecture naturally followed.

---

## Conclusion

Ultimately, the project transformed Wikimedia pageviews from a raw activity log into an entity-centric attention dataset capable of supporting cross-language analysis at global scale.

The resulting model preserves the integrity of the original observations while providing a semantic representation of how attention moves across entities, communities, and time.
