# MFA GLOBAL REPRESENTATION & COUNTRY OFFICES V1

## 1. Purpose and scope

This is an additive MFA V1 module. It establishes how MFA records agent operating locations and how the Super Admin manages official country representatives and country offices. It does not change MFA's role as a coordination and service-discovery platform and does not authorize payment execution, custody, settlement, or money movement.

## 2. Distinct records and roles

Keep these concepts separate:
- **Agent:** an independently registered service agent. Registration does not make the person an official MFA representative.
- **Country Representative:** a person formally appointed and approved by the Super Admin to represent MFA in a defined country or territory.
- **Country Office:** an official MFA office or approved public-facing office location. An agent's business or home address is not automatically an MFA office.

Only the Super Admin can appoint, approve, suspend, or remove a Country Representative and create, edit, verify, activate, or deactivate official Country Office records.

## 3. Agent registration location

Agent onboarding should collect the operational location fields needed to review service coverage:
- Country
- Region / state / province
- District / county
- City / town
- Ward
- Street / neighbourhood / area
- Business or service address
- Contact phone and email
- Service coverage areas

Where applicable, allow an agent to indicate whether the address is a business location, service point, or residential address. Collect only information necessary for onboarding and verification.

### Privacy rules
- Agent location details are private by default.
- Never publish a residential address by default.
- Public directory information must be limited to approved business/service location fields and must respect the agent's consent and applicable privacy requirements.
- Mask or restrict sensitive contact/location details in public views.
- Super Admin and specifically authorized reviewers may access private onboarding data for verification, with access logged.

## 4. Country Representative management

The Super Admin workspace should provide a Country Representatives section with fields such as:
- Country and territory
- Representative's legal/display name
- Official title
- Related organization or agency name, if applicable
- Public-facing city and region
- Official business address (if approved for publication)
- Official phone and email
- Appointment start date and optional end date
- Verification status
- Active / inactive / suspended status
- Internal notes and supporting verification references (private)

A representative becomes official only after explicit Super Admin appointment and verification. One country may have a primary representative and additional authorized representatives if the Super Admin configures that arrangement. Do not infer appointment from agent status or registration.

## 5. Country Office management

The Super Admin workspace should provide a separate Country Offices section with:
- Country
- Office/agency name
- Office type (head office, country office, regional office, service office)
- Region and city
- Official public address
- Official public phone and email
- Public website/contact details, where applicable
- Verification evidence/reference (private)
- Active / inactive status
- Public display toggle
- Effective dates and internal notes

An address must not be presented as an official MFA office until it has been verified and explicitly approved by the Super Admin. A representative's personal address must not be described as an office unless it is separately approved as an official public service location.

## 6. Public website and footer

The website footer may display only Country Representatives and Country Offices that are:
1. verified;
2. active;
3. explicitly approved for public display by the Super Admin; and
4. configured with public-facing fields.

The footer may show country, representative/office name, title, city, official address, official phone, and official email according to the public-display settings. A visitor may open a country details page to view approved information.

If no verified office or representative exists for a country, do not imply that MFA has an official presence there. Do not generate placeholder offices or claim legal registration, licensing, or government recognition without evidence and approval.

## 7. Super Admin workspace

Add the following management areas:
- Agent Registration Review
- Agent Location Review
- Country Representatives
- Country Offices
- Global Presence Management
- Footer Display Control
- Change/Audit History

Country and office records must be editable only by the Super Admin role. Country/regional managers and agents must not receive these permissions unless a later, separately approved role-and-policy design grants narrowly scoped access.

## 8. Suggested data model

Implementation may use separate tables or equivalent normalized records:
- `agent_location_profiles`: agent_id, country_code, region, district, city, ward, neighbourhood, address, location_type, public_listing_consent, service_areas, review_status, reviewed_by, reviewed_at.
- `country_representatives`: country_code, profile/person reference, display_name, title, organization_name, public_city, public_region, public_address, public_phone, public_email, verification_status, status, appointed_by, appointed_at, effective_from, effective_to, show_publicly.
- `country_offices`: country_code, office_name, office_type, region, city, public_address, public_phone, public_email, verification_status, status, verified_by, verified_at, show_publicly.
- `global_presence_audit_log`: actor_id, record_type, record_id, action, before/after metadata, created_at.

Use foreign keys, timestamps, constraints, and indexes appropriate to the existing schema. Avoid duplicating personal data when a secure profile reference is sufficient. Supporting documents must be stored privately, not in public buckets.

## 9. Authorization, security, and audit

- Enforce authorization in the database with Row Level Security and server-side checks; hiding UI controls is not security.
- Only Super Admin may create, appoint, verify, approve, activate, suspend, or change public-display settings for country representation records.
- Agents may submit and update their own onboarding location information subject to review; they cannot self-appoint or approve their own public listing.
- Public/anonymous visitors may read only active, verified, explicitly public fields.
- Keep private evidence, internal notes, personal/residential addresses, and review metadata inaccessible to public users.
- Record every privileged change with actor, timestamp, action, and affected record.
- Apply least-privilege access and test policies with anonymous, agent, ordinary admin (if later introduced), and Super Admin accounts.

## 10. Rollout and acceptance criteria

### Phase A — Blueprint and schema
Document fields, privacy classifications, role permissions, RLS policies, and audit requirements before implementation.

### Phase B — Agent location onboarding
Add location fields to agent registration/profile review. Keep new fields private until reviewed and consented for public display.

### Phase C — Super Admin management
Build representative and office management screens with verification, activation, public-display controls, and audit history.

### Phase D — Public directory and footer
Display only verified, active, approved public records. Ensure empty countries are not represented as having an official office.

Acceptance checks:
- Registering an agent does not create a Country Representative record.
- Only Super Admin can appoint a representative or approve an office.
- An unverified/inactive record never appears in the footer.
- A private/residential agent address never appears publicly by default.
- Public visitors cannot read private fields or evidence.
- Every privileged change is auditable.
- Existing MFA request, agent, partner, and demo-only payment-service workflows remain unchanged.

## 11. Explicit exclusions

This module does not itself establish a legal entity, company registration, licence, banking relationship, payment-provider mandate, or government recognition in any country. Public wording must accurately reflect the evidence and legal status of each presence. It does not authorize real payments or financial operations.
