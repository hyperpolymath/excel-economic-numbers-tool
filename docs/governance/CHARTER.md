<!--
SPDX-License-Identifier: MPL-2.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# Economic Toolkit Governance Charter - v10.0

**Effective Date:** January 23, 2026
**Version:** 1.0

## Mission

The Economic Toolkit project aims to democratize access to economic data and advanced analytics through open-source software, fostering a global community of economists, developers, researchers, and policymakers.

## Core Values

1. **Openness**: All development is conducted in public
2. **Inclusivity**: Everyone is welcome to contribute
3. **Quality**: Maintain high standards for code, documentation, and community interaction
4. **Sustainability**: Build for long-term viability
5. **Education**: Share knowledge and teach best practices

## Governance Structure

### 1. Steering Committee

**Role**: Strategic direction, major decisions, conflict resolution

**Composition**:
- 5-7 elected members
- Term: 2 years, staggered
- Maximum 2 consecutive terms
- Elections held annually in December

**Responsibilities**:
- Set project roadmap
- Approve major architectural changes
- Manage project assets (domain, trademarks, funds)
- Resolve escalated conflicts
- Appoint working group leads

**Decision Making**:
- Quorum: 50%+ members
- Approval: Simple majority
- Major changes: 2/3 supermajority

**Current Members** (Bootstrap):
- To be elected in first community election (Q1 2026)

### 2. Technical Advisory Board

**Role**: Technical guidance and architecture decisions

**Composition**:
- 3-5 technical experts
- Appointed by Steering Committee
- Term: 1 year, renewable

**Responsibilities**:
- Review RFCs for technical soundness
- Maintain technical standards
- Guide performance and security decisions
- Mentor contributors

### 3. Working Groups

**Purpose**: Focus on specific areas of the project

**Active Working Groups**:

1. **Core Platform**
   - Lead: TBD
   - Focus: Core functionality, APIs, performance
   - Meetings: Weekly

2. **Data Sources**
   - Lead: TBD
   - Focus: New data source integrations, data quality
   - Meetings: Bi-weekly

3. **User Experience**
   - Lead: TBD
   - Focus: UI/UX, accessibility, internationalization
   - Meetings: Bi-weekly

4. **Documentation**
   - Lead: TBD
   - Focus: Docs, tutorials, examples
   - Meetings: Monthly

5. **Community**
   - Lead: TBD
   - Focus: Events, outreach, onboarding
   - Meetings: Monthly

**Forming New Working Groups**:
- Proposal to Steering Committee
- Minimum 3 active members
- Clear charter and goals
- Regular meeting schedule

### 4. Contributors

**Types**:
- **Contributor**: Anyone who contributes (code, docs, design, etc.)
- **Regular Contributor**: 5+ merged contributions
- **Core Contributor**: Granted commit access, active for 6+ months
- **Emeritus**: Former core contributors

**Rights**:
- All contributors: Recognized in CONTRIBUTORS file
- Regular contributors: Vote in elections
- Core contributors: Commit access, RFC approval authority

**Responsibilities**:
- Follow Code of Conduct
- Maintain quality standards
- Participate constructively
- Mentor newcomers

## Decision Making Process

### 1. RFC (Request for Comments)

**When Required**:
- New features affecting public API
- Breaking changes
- Major architectural decisions
- Process changes

**Process**:
1. Author creates RFC document in `rfcs/` directory
2. Discussion period (minimum 1 week)
3. Technical Advisory Board review
4. Steering Committee approval for significant changes
5. Implementation begins after approval

**RFC Template**: See `rfcs/0000-template.md`

### 2. Lazy Consensus

**When Used**:
- Minor changes
- Bug fixes
- Documentation improvements
- Dependency updates

**Process**:
1. Propose change (PR or issue)
2. Wait 72 hours for objections
3. If no objections, proceed
4. Objections trigger discussion

### 3. Voting

**When Required**:
- Steering Committee elections
- Charter amendments
- Project asset decisions
- Escalated conflicts

**Eligible Voters**:
- Regular contributors (5+ merged contributions in past 12 months)
- Current Steering Committee members
- Technical Advisory Board members

**Voting Methods**:
- Elections: Condorcet/IRV
- Yes/No decisions: Simple majority
- Charter amendments: 2/3 supermajority

## Contribution Process

### Code Contributions

1. **Discuss**: Open issue or discussion for significant changes
2. **Implement**: Fork, branch, code, test
3. **Submit**: Create pull request with clear description
4. **Review**: Address feedback from maintainers
5. **Merge**: Approved PRs merged by core contributors

**Requirements**:
- Tests pass
- Code follows style guide
- Documentation updated
- SPDX headers present
- Signed-off commits (DCO)

### Other Contributions

- **Documentation**: Same PR process
- **Translations**: Submit via i18n working group
- **Designs**: Share in discussions, iterate with UX group
- **Bug Reports**: Use issue template, provide reproduction steps
- **Feature Requests**: Discuss in GitHub Discussions first

## Code of Conduct

**Summary**: Be respectful, inclusive, and professional.

**Full Text**: See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)

**Enforcement**:
- Reports to: conduct@economictoolkit.org
- Handled by: Steering Committee (minus conflicted members)
- Outcomes: Warning, temporary ban, permanent ban
- Appeals: To full Steering Committee

## Financial Management

**Revenue Sources**:
- Donations (Open Collective)
- Sponsorships (companies using the project)
- Certification fees (ETCA program)
- Conference proceeds
- Grants

**Allocation**:
- Infrastructure: 30%
- Contributor stipends: 30%
- Events and outreach: 20%
- Marketing: 10%
- Reserve: 10%

**Oversight**:
- Steering Committee approves budget
- Treasurer (Steering Committee member) manages funds
- Quarterly financial reports published
- Annual audit for transparency

## Conflict Resolution

### Process

1. **Direct Resolution**: Parties attempt to resolve directly
2. **Working Group Lead**: Escalate to relevant working group lead
3. **Steering Committee**: Escalate if unresolved
4. **Mediation**: External mediator if needed
5. **Final Decision**: Steering Committee vote (binding)

### Types of Conflicts

- **Technical**: Technical Advisory Board mediates
- **Process**: Steering Committee decides
- **Personal**: Follow Code of Conduct procedures
- **Legal**: Legal counsel consulted

## Intellectual Property

**Copyright**:
- Contributors retain copyright
- Code licensed under MPL-2.0
- Documentation licensed under CC-BY-4.0

**Patents**:
- Contributors grant patent license per MPL-2.0
- No patent trolling allowed

**Trademarks**:
- "Economic Toolkit" trademark owned by project
- Steering Committee manages trademark policy
- Community can use for non-commercial purposes

**Contributor License Agreement**:
- Developer Certificate of Origin (DCO) required
- Sign-off on all commits (`git commit -s`)
- No separate CLA needed

## Charter Amendments

**Process**:
1. Proposal in GitHub Discussion
2. Community feedback (minimum 2 weeks)
3. Steering Committee vote
4. Approval: 2/3 supermajority
5. Announcement and implementation

**Ratification**:
- First charter: Bootstrap approval
- Future amendments: Above process

## Succession Planning

**Project Continuation**:
- All assets held in trust for community
- Steering Committee succession via elections
- Emergency procedures for inactivity

**Asset Transfer**:
- If project discontinues, assets to similar open-source projects
- Steering Committee vote required

## Contact Information

- **General**: hello@economictoolkit.org
- **Governance**: governance@economictoolkit.org
- **Code of Conduct**: conduct@economictoolkit.org
- **Security**: security@economictoolkit.org
- **Press**: press@economictoolkit.org

## Acknowledgments

This charter was inspired by:
- Apache Software Foundation Governance
- Python Software Foundation
- Rust Foundation
- Kubernetes Steering Committee

---

**Signed** (Bootstrap Approval):
Hyperpolymath Contributors
January 23, 2026

**Next Review**: January 2027
