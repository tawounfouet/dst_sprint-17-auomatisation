from django.core.management.base import BaseCommand, CommandError
from django_celery_beat.models import IntervalSchedule, PeriodicTask


class Command(BaseCommand):
    help = "Create or update the demo Celery Beat heartbeat schedule."

    def add_arguments(self, parser):
        parser.add_argument("--seconds", type=int, default=30)

    def handle(self, *args, **options):
        seconds = options["seconds"]
        if seconds < 5 or seconds > 3600:
            raise CommandError("--seconds must be between 5 and 3600")

        interval, _ = IntervalSchedule.objects.get_or_create(
            every=seconds,
            period=IntervalSchedule.SECONDS,
        )

        name = "datascientest-demo-heartbeat"
        defaults = {
            "task": "tasks_demo.periodic_heartbeat",
            "interval": interval,
            "enabled": True,
            "args": "[]",
            "kwargs": "{}",
        }

        periodic_task, created = PeriodicTask.objects.get_or_create(
            name=name,
            defaults=defaults,
        )

        if created:
            self.stdout.write("created")
            return

        changed = False
        for field, value in defaults.items():
            if getattr(periodic_task, field) != value:
                setattr(periodic_task, field, value)
                changed = True

        if changed:
            periodic_task.save()
            self.stdout.write("updated")
        else:
            self.stdout.write("unchanged")
