# Generated by Django 2.2.3 on 2019-07-18 13:23

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('schedule', '0001_initial'),
    ]

    operations = [
        migrations.AlterField(
            model_name='scheduleentry',
            name='schedule',
            field=models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='entry', to='schedule.Schedule', verbose_name='Schedule'),
        ),
    ]