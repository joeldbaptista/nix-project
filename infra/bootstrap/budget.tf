# The budget is the backstop for the cost control that the durable/ephemeral
# split provides. It lives in bootstrap so that it exists before any chargeable
# resource does, and so that destroying the ephemeral layer never removes it.
#
# The budget covers the whole account rather than filtering on the Project tag.
# A tag filter would require the tag to be activated as a cost allocation tag in
# the Billing console first, which takes up to 24 hours to take effect, and an
# unactivated filter matches nothing and fires no notification at all. The
# account is a development account for this project, so account-wide is both
# simpler and safer.
resource "aws_budgets_budget" "monthly" {
  name         = "${var.project}-monthly"
  budget_type  = "COST"
  limit_amount = var.budget_limit_amount
  limit_unit   = var.budget_limit_unit
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = [50, 80, 100]

    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.budget_notification_email]
    }
  }

  # Forecast crossing the limit is the earlier warning, so it is worth its own
  # notification rather than waiting for the spend to actually arrive.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_notification_email]
  }
}
