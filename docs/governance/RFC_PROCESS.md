<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# RFC (Request for Comments) Process - v10.0

## Purpose

The RFC process is used to propose, discuss, and decide on significant changes to the Economic Toolkit project. It ensures transparency, community input, and thoughtful decision-making.

## When to Use RFC

### Required

- New features affecting public API
- Breaking changes to existing functionality
- Major architectural decisions
- New dependencies or technology choices
- Process or governance changes
- Security-sensitive changes

### Not Required (Use lazy consensus)

- Bug fixes
- Documentation improvements
- Minor refactoring
- Performance improvements (non-breaking)
- Test additions
- Dependency updates (patch/minor)

## RFC Lifecycle

```
Draft → Discussion → Review → Decision → Implementation → Complete
  ↓                                ↓
  └────────────→ Rejected ←───────┘
                    or
               Withdrawn
```

### States

- **Draft**: RFC is being written
- **Discussion**: Open for community feedback
- **Review**: Technical Advisory Board reviewing
- **Decision**: Steering Committee deciding
- **Accepted**: Approved, ready for implementation
- **Rejected**: Not approved
- **Withdrawn**: Author withdrew proposal
- **Implemented**: Code merged
- **Complete**: Shipped in release

## Process Steps

### 1. Pre-RFC Discussion

Before writing full RFC:
1. Open GitHub Discussion
2. Describe problem and proposed solution
3. Gauge community interest
4. Refine idea based on feedback

### 2. Create RFC Document

1. Fork repository
2. Copy `rfcs/0000-template.md` to `rfcs/0000-my-feature.md`
3. Fill in template sections
4. Submit pull request

**PR Title Format**: `RFC: [Feature Name]`

### 3. Discussion Period

**Duration**: Minimum 1 week, typically 2-4 weeks

**Activities**:
- Community comments on PR
- Author responds and updates RFC
- Alternative approaches discussed
- Edge cases identified

**Participants**:
- Anyone can comment
- Core contributors provide guidance
- Technical Advisory Board monitors

### 4. Technical Review

**Reviewers**: Technical Advisory Board

**Review Criteria**:
- Technical soundness
- Alignment with project architecture
- Performance implications
- Security considerations
- Testing strategy
- Documentation needs

**Outcomes**:
- **Approve**: Move to decision phase
- **Request Changes**: Author revises
- **Reject**: Not technically viable

### 5. Decision

**Decision Makers**:
- **Minor changes**: Working group leads
- **Significant changes**: Steering Committee

**Decision Criteria**:
- Community feedback sentiment
- Technical Advisory Board recommendation
- Resource availability
- Strategic fit
- Risk assessment

**Possible Outcomes**:
- **Accept**: RFC approved, assign number, merge PR
- **Reject**: Provide reasons, close PR
- **Defer**: Good idea, wrong timing
- **Request Major Changes**: Needs redesign

### 6. Implementation

After acceptance:
1. Create implementation tracking issue
2. Link RFC in issue
3. Break work into tasks
4. Implement per RFC
5. Update RFC with lessons learned

**Changes During Implementation**:
- Minor: Document in RFC "Amendments" section
- Major: New RFC or RFC update with discussion

### 7. Completion

When shipped:
1. Update RFC state to "Complete"
2. Add "Shipped in" version note
3. Link to final implementation
4. Update documentation

## RFC Template

See `rfcs/0000-template.md` for complete template.

**Key Sections**:
- **Summary**: One paragraph overview
- **Motivation**: Why is this needed?
- **Guide-level explanation**: How will users experience it?
- **Reference-level explanation**: Technical details
- **Drawbacks**: What are the downsides?
- **Rationale and alternatives**: Why this approach?
- **Prior art**: What do others do?
- **Unresolved questions**: What needs more discussion?
- **Future possibilities**: What could build on this?

## Best Practices

### For RFC Authors

- **Start small**: Get feedback early
- **Be specific**: Provide examples and use cases
- **Consider alternatives**: Show you've explored options
- **Listen actively**: Be open to feedback
- **Iterate**: Revise based on comments
- **Stay engaged**: Respond to questions promptly

### For Reviewers

- **Be constructive**: Suggest improvements, not just problems
- **Be specific**: Point to concrete issues
- **Be respectful**: Disagree without being disagreeable
- **Be timely**: Review promptly
- **Focus on substance**: Not just style
- **Ask questions**: Clarify understanding

### For Steering Committee

- **Consider impact**: How does this affect users?
- **Balance interests**: Technical vs. community vs. business
- **Be transparent**: Document decision rationale
- **Be timely**: Don't let RFCs linger
- **Be fair**: Apply consistent criteria

## Special Cases

### Security RFCs

- Discuss in private security channel
- Limited distribution until fix released
- Expedited review if actively exploited
- Public RFC published with fix

### Breaking Changes

- Require deprecation path
- Migration guide needed
- Major version bump
- Extra scrutiny on necessity

### Experimental Features

- Can use feature flags
- Document as experimental
- May iterate without RFC
- Full RFC before stabilization

## Metrics

Track RFC health:
- Time to decision (target: < 6 weeks)
- Accept/reject ratio
- Implementation completion rate
- Community participation level

## Examples

### Accepted RFCs

- **RFC-0001**: Python API wrapper
- **RFC-0005**: Plugin system architecture
- **RFC-0012**: GraphQL API design

### Rejected RFCs

- **RFC-0003**: Blockchain data persistence (unnecessary complexity)
- **RFC-0008**: Built-in ad system (against values)
- **RFC-0015**: Remove all dependencies (impractical)

## FAQ

**Q: Can anyone submit an RFC?**
A: Yes, anyone can submit. Core contributors and frequent contributors' RFCs may get more attention.

**Q: How long does the process take?**
A: Typically 4-8 weeks from submission to decision. Simple RFCs faster, controversial ones slower.

**Q: What if my RFC is rejected?**
A: You'll receive clear rationale. You can revise and resubmit, or propose an alternative approach.

**Q: Can I implement before RFC is accepted?**
A: You can prototype, but don't expect it to merge without approved RFC.

**Q: Do all features need RFCs?**
A: No, only significant changes. Use judgment or ask a core contributor.

**Q: What if implementation differs from RFC?**
A: Update RFC with amendments or create new RFC for major changes.

## Contact

- **RFC Questions**: governance@economictoolkit.org
- **Technical Review**: tech-board@economictoolkit.org
- **Process Issues**: steering@economictoolkit.org

---

**Last Updated**: January 23, 2026
**Next Review**: January 2027
