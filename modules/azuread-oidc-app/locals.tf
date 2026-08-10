locals {
  secret_name_prefix = coalesce(var.secret_name_prefix, var.app_display_name)

  # Deterministic role IDs so they don't churn across applies.
  role_ids = { for r in var.roles : r.name => uuidv5("oid", "${var.app_display_name}-${r.name}") }

  # Flatten { role_name = [principal, ...] } into one row per assignment,
  # keyed uniquely so for_each can manage them individually.
  assignment_pairs = flatten([
    for role_name, principals in var.role_assignments : [
      for principal_id in principals : {
        key                 = "${role_name}-${principal_id}"
        role_name           = role_name
        principal_object_id = principal_id
      }
    ]
  ])
  assignments_by_key = { for a in local.assignment_pairs : a.key => a }

  # Every principal that has any role, deduplicated — used for the
  # "who is allowed in at all" Key Vault secret.
  all_assigned_principals = distinct(flatten(values(var.role_assignments)))
}
