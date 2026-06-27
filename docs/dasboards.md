# Dashboard Design

## Introduction

Building the attention dataset answered only part of the problem.

Once pageviews had been transformed into entities and enriched with semantic information, a new challenge emerged:

> What questions can this data answer?

The original objective of the project was simple:

> What are people paying attention to?

However, attention quickly proved to be a richer concept than simple popularity.

Attention moves through time, spreads across communities, concentrates around specific topics, and sometimes escapes the model entirely.

Through several iterations, four analytical themes emerged:

1. What is receiving attention?
2. How is attention shifting?
3. How is attention distributed across communities?
4. What part of attention is not captured by the model?

Each dashboard represents a different projection of the same attention model.

Together they form a progression from observation to explanation.

---

# Dashboard 1 — What Are People Paying Attention To?

## The Question

Before studying trends or communities, it is useful to understand attention in its most direct form.

The objective of this dashboard is descriptive.

Rather than introducing derived metrics, it presents the attention dataset as observed.

The dashboard serves as the baseline reference for the rest of the project.

---

## Why This Dashboard Exists

Many analytical dashboards begin immediately with rankings and scores.

This dashboard intentionally avoids that approach.

Before discussing how attention changes, it is important to understand where attention is currently concentrated.

The dashboard provides a direct view of the attention landscape during the analysis period.

---

## Dashboard Outputs

The dashboard includes:

* Total views during the analysis period
* Daily attention evolution
* Attention distribution by language community
* Most viewed entities
* Most viewed entity types
* Attention distribution by viewing medium (mobile versus desktop)

---

## Purpose

This dashboard answers:

> What is receiving attention?

The remaining dashboards explore how that attention evolves, spreads, and escapes the model.

---

# Dashboard 2 — Attention Shifting

## The Question

Popularity is only one aspect of attention.

The more interesting question is often:

> What is changing?

An entity attracting ten million views may be important, but an entity rapidly gaining attention may be more informative.

The goal of this dashboard is therefore to identify movement rather than magnitude.

---

## Defining Trend

Trend appears intuitive until it must be translated into a metric.

Several possible definitions exist:

* Growth between the start and end of the period
* Current acceleration
* Sustained increase
* Sudden bursts of activity

Each captures a different behavior.

The objective was to build a metric that rewards sustained recent movement while remaining robust to extreme differences in scale.

---

## Defining Trend

Trend appears intuitive until it must be translated into a metric.

At first glance, several definitions seem reasonable:

* An entity ends the period with more views than it started with.
* An entity is currently growing.
* An entity experienced rapid growth.
* An entity experienced sustained growth.

The challenge is that each definition rewards different behavior.

Before building a metric, I first needed to decide what behavior I wanted the metric to surface.

The goal was not simply to identify popular entities.

The goal was to identify entities whose attention was meaningfully changing.

---

## First Attempt: Growth

The most obvious metric was simple growth.

Growth is easy to interpret and immediately highlights entities receiving additional attention.

However, growth alone proved problematic.

Small entities could dominate the rankings after relatively modest increases in views, while globally important entities gaining hundreds of thousands or even millions of views could appear less significant.

The metric captured change but ignored scale.

Growth was therefore retained as a descriptive measure but rejected as the primary trend indicator.

---

## Second Attempt: Momentum

To reintroduce scale, I experimented with a momentum score:

Momentum = Growth × √Views

The intuition was simple.

An entity should receive a higher score if it is both growing and attracting meaningful attention.

This partially solved the scale issue but introduced another problem.

The metric strongly favored burst-like behavior.

Entities experiencing sudden spikes frequently dominated the rankings, even when the increase was short-lived.

Interestingly, this failure made the metric useful for a different purpose.

Rather than measuring trend, it became a reasonable proxy for burst detection.

The metric was therefore retained elsewhere in the analysis.

---

## Looking Beyond Growth

At this stage I realized that growth itself might not be the correct quantity to measure.

Growth only compares two points in time.

It ignores everything that happens between them.

An entity that gradually increases over several days and an entity that explodes on the final day can exhibit similar growth despite representing very different behaviors.

What I actually wanted to measure was not growth.

It was direction.

More specifically:

> Is attention consistently moving upward or downward?

This naturally led to the concept of slope.

---

## Smoothing The Signal

Unfortunately, raw pageview data is noisy.

Day-to-day fluctuations can be substantial, particularly for smaller entities.

Computing a slope directly on raw views produced unstable results.

To approximate the underlying trend, I introduced a moving average.

A moving average smooths short-term fluctuations and provides a better estimate of the recent direction of the series.

The first implementation used a seven-day moving average.

While effective at reducing noise, it created an unintended consequence.

Large bursts continued influencing the trend score for nearly a week after they occurred.

The metric became slow to forget.

---

## Choosing A Three-Day Window

To make the metric more responsive, I reduced the smoothing window from seven days to three days.

This increased sensitivity to recent changes while still providing enough smoothing to suppress most day-to-day noise.

The shorter window also aligned better with the objective of identifying emerging shifts in attention rather than long-term historical trends.

The trade-off was higher variance, but this was considered acceptable for an exploratory dashboard.

---

## Solving The Scale Problem

The final challenge was scale.

Wikipedia attention spans several orders of magnitude.

Without adjustment, small entities can dominate rankings simply because percentage changes are easier to achieve at low volumes.

To compress these differences, daily views were transformed using a logarithm.

The logarithmic transformation preserves relative behavior while preventing extremely large entities from overwhelming the metric.

However, using only the slope of log-transformed views introduced a new issue.

The metric now treated a change affecting a niche entity and a change affecting a globally visible entity similarly.

A notion of attention magnitude needed to be reintroduced.

The solution was to weight the directional signal using the recent level of attention represented by the moving average itself.

---

## Final Trend Score

The final metric combines:

* Log-transformed daily views
* A three-day moving average
* The slope of the smoothed series
* A scale adjustment based on recent attention

Conceptually, the metric can be interpreted as:

> A weighted measure of the recent direction of attention.

The score rewards entities experiencing sustained movement while still favoring entities attracting meaningful levels of attention.

Importantly, the objective was never to build a universal trend metric.

The objective was to build a metric that surfaced the kinds of attention shifts that were interesting within the context of this dataset.

---

## Anomaly Detection

Trend and anomaly are not the same phenomenon.

An entity can be stable but anomalous.

To identify unexpected behavior, a simple z-score was computed using recent history as a baseline.

This highlights entities receiving significantly more or less attention than expected.

---

## Dashboard Outputs

The dashboard includes:

* Trending entities
* Declining entities
* Burst detection
* Anomaly detection
* Attention evolution over time

---

# Dashboard 3 — Attention Across Communities

## The Question

Attention is not distributed uniformly across Wikipedia.

Different communities often focus on different topics.

The challenge was determining how to compare attention across communities without simply reproducing language-size effects.

---

## Attention and Coverage

To structure the problem, two complementary dimensions were introduced:

* Attention
* Coverage

Attention measures the relative importance of an entity within communities.

Coverage measures how many communities discuss that entity.

Together these dimensions make it possible to distinguish globally important topics from locally important ones.

---

## Global Stars

Global stars combine:

* High attention
* Broad coverage

These are entities that attract meaningful attention across many communities simultaneously.

The score rewards both relative importance and cross-language reach.

---

## Local Stars

Local stars attract significant attention while remaining concentrated within a limited number of communities.

These entities often reflect regional interests, local events, or culturally specific topics.

The score rewards attention while penalizing excessive coverage.

---

## Coverage Versus Attention

The dashboard also explores whether visibility naturally expands into additional communities.

This relationship is visualized using:

* Attention share
* Concurrent language count

and quantified through:

* Pearson correlation
* Spearman rank correlation

The objective is exploratory rather than predictive.

---

## Dashboard Outputs

The dashboard includes:

* Attention distribution by community
* Global stars
* Local stars
* Coverage versus attention analysis
* Community-level filtering

---

# Dashboard 4 — Uncaptured Attention

## The Question

No model captures reality perfectly.

The final dashboard focuses on the attention that remains unmatched after entity resolution.

Initially, unmatched attention appeared to represent modeling failures.

The reality proved more nuanced.

---

## Understanding Unmatched Attention

Several situations produce unmatched pageviews.

### Emerging Concepts

The page exists, but the corresponding entity has not yet been created.

### Wikimedia Infrastructure

Namespaces such as Main Page, Search, File, and other internal utilities are not semantic concepts and therefore cannot be matched meaningfully.

### Missing Sitelinks

The entity and page exist, but the relationship between them has not yet been recorded.

---

## Concentration Analysis

The objective is not simply to measure unmatched attention but to understand its structure.

A healthy unmatched space should resemble residual noise:

* Many entities
* Low concentration
* Long-tailed behavior

High concentration may indicate systematic modeling gaps.

---

## Trending Unmatched Entities

The same trend metric used throughout the project is applied to unmatched entities.

This makes it possible to identify:

* Emerging concepts
* Newly created pages
* Potential reconciliation opportunities

These entities represent the most valuable candidates for future improvements.

---

## Dashboard Outputs

The dashboard includes:

* Unmatched views
* Unmatched entities
* Unmatched attention by community
* Concentration analysis
* Trending unmatched entities

---

# Conclusion

The dashboards are not independent products.

They are complementary views of the same attention model.

Together they explore four dimensions of collective attention:

* What receives attention
* How attention changes
* How attention spreads
* What attention remains unexplained

The result is a system designed not only to describe collective attention, but also to investigate how it emerges, evolves, and propagates across Wikipedia's global network of communities.
