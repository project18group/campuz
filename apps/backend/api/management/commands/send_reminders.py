from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from api.models import TaskItem
from api.services.push_service import send_push_notification

class Command(BaseCommand):
    help = 'Scans for upcoming tasks and sends push notification reminders to assigned users.'

    def handle(self, *args, **kwargs):
        now = timezone.now()
        # Look for tasks due in exactly 24 hours (with a 1 hour window to avoid spam)
        # In a real production app, we would mark "reminder_sent" on the TaskItem
        # but for this prototype, checking the time window is sufficient.
        time_threshold_start = now + timedelta(hours=23)
        time_threshold_end = now + timedelta(hours=24)

        upcoming_tasks = TaskItem.objects.filter(
            due_date__gte=time_threshold_start,
            due_date__lte=time_threshold_end,
            status='pending'
        )

        sent_count = 0
        for task in upcoming_tasks:
            # Send to the assigned user
            success = send_push_notification(
                user=task.assigned_to,
                hub=task.hub,
                title="Upcoming Deadline!",
                body=f"Your task '{task.title}' is due in 24 hours.",
                data={"task_id": str(task.id), "type": "reminder"}
            )
            if success:
                sent_count += 1
                self.stdout.write(self.style.SUCCESS(f"Sent reminder to {task.assigned_to.username} for task {task.id}"))
        
        # Also check for 1-hour reminders
        hour_start = now + timedelta(minutes=55)
        hour_end = now + timedelta(minutes=65)
        imminent_tasks = TaskItem.objects.filter(
            due_date__gte=hour_start,
            due_date__lte=hour_end,
            status='pending'
        )

        for task in imminent_tasks:
            success = send_push_notification(
                user=task.assigned_to,
                hub=task.hub,
                title="Deadline Imminent!",
                body=f"Your task '{task.title}' is due in 1 hour.",
                data={"task_id": str(task.id), "type": "reminder"}
            )
            if success:
                sent_count += 1
                self.stdout.write(self.style.SUCCESS(f"Sent 1hr reminder to {task.assigned_to.username} for task {task.id}"))

        self.stdout.write(self.style.SUCCESS(f'Successfully sent {sent_count} reminders.'))
