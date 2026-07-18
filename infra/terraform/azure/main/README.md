# Prod v/s Staging
- Staging is the same infrastructure as Prod but with lesser specs.
- Any changes to infra is first applied on staging and tested for stability, performance, efficiency and other standards.
- Once tested and approved, the same structure is enforced upon `Prod` as well.
- This behaviour is avhieved by maintaining different terraform profiles, and different tfvars files.