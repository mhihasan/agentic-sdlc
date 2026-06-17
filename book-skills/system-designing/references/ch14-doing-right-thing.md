# Chapter 14: Doing the Right Thing

## Core Thesis
Data systems are not neutral tools. They embed values, create power asymmetries, and have
real-world consequences for the people whose data they process. Engineers who build these
systems have ethical and professional responsibilities that go beyond technical correctness.

---

## Predictive Analytics and Algorithmic Decision-Making

```mermaid
graph LR
    DATA[Data about people] -->|ML model| PREDICT[Predictions / Scores]
    PREDICT --> DECISION[Automated decisions]
    DECISION --> IMPACT[Real impacts on people:<br/>Loan approvals / rejections<br/>Job screening<br/>Bail / parole decisions<br/>Insurance premiums<br/>Advertising targeting]

    note1[When algorithmic, decisions are:<br/>• Hard to challenge or explain<br/>• Applied at massive scale<br/>• May amplify historical bias<br/>• May discriminate on protected characteristics]
```

---

## Bias and Discrimination

### Sources of Bias

```mermaid
graph TD
    B1[Training data bias<br/>Historical decisions reflect past discrimination<br/>→ model learns to discriminate] 
    B2[Feature selection bias<br/>Proxy variables correlate with protected attributes<br/>e.g., zip code ≈ race]
    B3[Feedback loops<br/>Model's predictions change future data<br/>→ model becomes self-fulfilling prophecy]
    B4[Measurement bias<br/>Different accuracy for different groups<br/>→ false positive rates differ by race]

    B1 --> HARM[Discriminatory outcomes]
    B2 --> HARM
    B3 --> HARM
    B4 --> HARM
```

### The Feedback Loop Problem

```mermaid
graph LR
    MODEL[Crime prediction model] -->|flag neighborhood as high-risk| POLICE[Police patrol high-risk areas more]
    POLICE -->|more arrests in that neighborhood| DATA[More crime data from that neighborhood]
    DATA -->|reinforces| MODEL
    note1[Self-fulfilling prophecy:<br/>Model creates the pattern it predicts<br/>Ground truth = model's predictions]
```

This applies equally to: search ranking, social media feeds, credit scoring, hiring tools.

---

## Privacy

```mermaid
graph TD
    COLLECT[Data collection<br/>Often invisible to user] --> STORE[Data storage<br/>Indefinite retention default]
    STORE --> PROC[Data processing<br/>Beyond original purpose]
    PROC --> SHARE[Data sharing<br/>Third parties, governments]
    SHARE --> HARM2[Potential harms:<br/>Surveillance, discrimination,<br/>manipulation, identity theft]
```

### Surveillance vs. Privacy

| Surveillance State View | Privacy-Respecting View |
|------------------------|------------------------|
| More data = better product | Minimum necessary data collection |
| Data is an asset to maximize | Data is a liability to minimize |
| Users consent via Terms of Service | Meaningful informed consent |
| Aggregate data is anonymous | Aggregates can be re-identified |
| Data helps us serve you better | User controls their own data |

**Re-identification risk**: "Anonymous" datasets frequently can be de-anonymized by
combining with external data. AOL search query release (2006), Netflix prize dataset
re-identification — both supposedly anonymous datasets were linked to individuals.

---

## GDPR and Data Governance Principles

```mermaid
graph TD
    GDPR[GDPR / Privacy by Design Principles]
    GDPR --> PP[Purpose limitation<br/>Collect only for stated purpose<br/>Cannot use for incompatible purposes]
    GDPR --> DM[Data minimization<br/>Collect minimum necessary data]
    GDPR --> SR[Storage limitation<br/>Delete when no longer needed]
    GDPR --> RT[Rights:<br/>Access, rectification, erasure (right to be forgotten),<br/>portability, objection to profiling]
    GDPR --> AC[Accountability<br/>Document processing activities<br/>DPIAs for high-risk processing]
```

**Right to be forgotten — technical challenge**:

```mermaid
graph LR
    DEL[User requests deletion] --> PG3[(PostgreSQL<br/>Delete row)]
    DEL --> KF2[Kafka<br/>Cannot delete from immutable log]
    DEL --> BQ[(Data Warehouse<br/>Delete from tables)]
    DEL --> ES3[(Elasticsearch<br/>Delete document)]
    DEL --> BAK[Backups<br/>?? Cannot easily delete from backups]
    note1[Deletion from an event-sourced system is architecturally hard<br/>Encryption-based erasure: encrypt user data with per-user key<br/>→ delete key = data becomes unreadable]
```

**Cryptographic erasure**: Encrypt user data with a per-user key stored separately.
To "delete" the user, delete their encryption key. Data remains in logs but is unreadable.

---

## Responsibility and Accountability

### The Engineer's Responsibility

```mermaid
graph TD
    TECH[Technical decision] --> CONSEQUENCES[Real-world consequences]
    CONSEQUENCES --> AFFECTED[Affected people]
    note1[Engineers are not neutral implementers<br/>Technical choices embed values<br/>Professional responsibility to consider impacts]
```

**Questions to ask when building data systems**:
1. Whose data is this, and did they meaningfully consent to this use?
2. What decisions will be made from this data, and who is harmed if wrong?
3. Does this system create or amplify existing power imbalances?
4. What are the failure modes, and who bears the cost?
5. Could this system be used for surveillance or control?
6. Have we tested for disparate impact across demographic groups?

---

## Data as Power

```mermaid
graph LR
    DATA2[Data about people] --> POWER[Power over those people]
    POWER --> CORP[Corporate power:<br/>Behavioral manipulation,<br/>price discrimination]
    POWER --> GOV[Government power:<br/>Surveillance, social control]
    POWER --> ASYM[Power asymmetry:<br/>Subject has no visibility<br/>into what is collected/inferred]
```

**The historical parallel**: The industrial revolution created concentrated economic power
that required regulation (labor laws, antitrust, environmental regulations) to protect
individuals. The data economy may require similar structural responses.

---

## Legislation and Self-Regulation

### Major Regulatory Frameworks

```mermaid
graph TD
    REG[Data Regulation Landscape]
    REG --> GDPR2[GDPR — EU 2018<br/>Strongest global standard<br/>Up to 4% global revenue fines<br/>Rights: access, erasure, portability, objection]
    REG --> CCPA[CCPA/CPRA — California<br/>Right to know, delete, opt-out of sale<br/>Model for US state privacy laws]
    REG --> HIPAA[HIPAA — US Healthcare<br/>Protected health information (PHI)<br/>Breach notification required]
    REG --> PCI[PCI-DSS — Payment Card Industry<br/>Card data handling standards<br/>Required for any merchant accepting cards]
    REG --> AI_REG[EU AI Act 2024<br/>Risk-based regulation of AI systems<br/>High-risk AI: hiring, credit, healthcare<br/>Prohibited: social scoring, real-time biometrics]
```

### Technical Implications of Regulation

| Regulation | Engineering implication |
|-----------|------------------------|
| GDPR right to erasure | Deletion from all stores including event logs (cryptographic erasure) |
| GDPR data minimization | Don't collect fields you don't need — architectural discipline |
| GDPR data residency | Multi-region deployment; no cross-border data transfer without safeguards |
| PCI-DSS | Tokenization of card numbers; audit logs; encryption at rest and in transit |
| HIPAA | Audit trails for all PHI access; business associate agreements with vendors |
| EU AI Act | Explainability requirements for high-risk decisions; human oversight mechanisms |

### Self-Regulation vs Government Regulation

```mermaid
graph LR
    SR[Industry self-regulation] --> SR1[Faster to implement<br/>Industry knows its domain<br/>Flexible]
    SR --> SR1b[Historically weak<br/>No enforcement mechanism<br/>Race to the bottom on privacy]

    GR[Government regulation] --> GR1[Enforceable penalties<br/>Level playing field<br/>Protects public interest]
    GR --> GR1b[Slow to adapt<br/>May stifle innovation<br/>Varies by jurisdiction]

    BOTH[Reality: Both needed<br/>Regulation sets floor<br/>Engineering practices build above it]
```

**DDIA's position**: Data-intensive applications have real-world consequences for real people.
Engineers bear responsibility for the systems they build. Waiting for regulation is not an
ethical stance — technical decisions embed values whether you intend them to or not.

---

## Practical Engineering Checklist

For any data system that processes personal data:

| Concern | Questions |
|---------|-----------|
| Data collection | Is this data necessary? Have users consented? |
| Data retention | How long is it kept? Is there an automatic deletion policy? |
| Access control | Who can access this data? Is access logged? |
| Sharing | Is data shared with third parties? Do users know? |
| Algorithmic decisions | Are automated decisions explainable? Is there a human override? |
| Bias testing | Have outputs been tested for disparate impact? |
| Security | Is data encrypted at rest and in transit? What's the breach response plan? |
| Deletion | Can individual data be deleted if requested? From all systems including logs? |

---

## Summary: The Ethical Engineer

```mermaid
graph TD
    T1[Build technically correct systems] --> BASE[Necessary but insufficient]
    BASE --> T2[Consider who is affected and how]
    T2 --> T3[Design with privacy by default]
    T3 --> T4[Test for bias and disparate impact]
    T4 --> T5[Support user rights and agency]
    T5 --> T6[Document decisions and their trade-offs]
    T6 --> GOAL[Systems that are both technically excellent<br/>and socially responsible]
```

The technical and ethical dimensions of data systems are not separable. Every architectural
decision about data collection, retention, sharing, and use has ethical implications. The
engineer who understands both is more valuable — and more responsible — than one who
understands only the technical side.
