import csv
import json
from io import TextIOWrapper

from django.contrib import messages
from django.contrib.admin.views.decorators import staff_member_required
from django.contrib.auth.decorators import login_required
from django.core.exceptions import ValidationError
from django.http import HttpResponse, HttpResponseRedirect, JsonResponse
from django.shortcuts import get_object_or_404, redirect, render, reverse
from django.template import Context, loader
from django.utils.translation import ugettext_lazy as _
from django.views.decorators.cache import cache_page
from django.views.decorators.http import require_http_methods
from django.views.decorators.vary import vary_on_cookie

from conferences.models import UserPreferences, Zosia
from .forms import UploadFileForm
from .models import Room, UserRoom
from .serializers import room_to_dict, user_to_dict


# Cache hard (15mins)
@cache_page(60 * 15)
@vary_on_cookie
@login_required
@require_http_methods(['GET'])
def index(request):
    # Return HTML w/ rooms layout
    return render(request, 'rooms/index.html')


# GET
@vary_on_cookie
@login_required
@require_http_methods(['GET'])
def status(request):
    # Ajax
    # Return JSON view of rooms
    zosia = get_object_or_404(Zosia, active=True)
    can_start_rooming = zosia.can_start_rooming(
        get_object_or_404(UserPreferences, zosia=zosia, user=request.user))
    rooms = Room.objects.all_visible().select_related('lock').prefetch_related(
        'members').all()
    rooms_view = []
    for room in rooms:
        dic = room_to_dict(room)
        dic['is_owned_by'] = room.is_locked and room.lock.is_owned_by(
            request.user) and room.lock.password
        dic['people'] = list(map(user_to_dict, room.members.all()))
        dic['inside'] = request.user.pk in map(lambda x: x.pk, room.members.all())
        rooms_view.append(dic)

    view = {
        'can_start_rooming': can_start_rooming,
        'rooms': rooms_view,
    }
    return JsonResponse(view)


@login_required
@require_http_methods(['POST'])
def join(request, room_id):
    zosia = get_object_or_404(Zosia, active=True)
    room = get_object_or_404(Room, pk=room_id)
    password = request.POST.get('password', '')
    if not zosia.can_start_rooming(
            get_object_or_404(UserPreferences, zosia=zosia, user=request.user)):
        return JsonResponse({'error': 'cannot_room_yet'}, status=400)

    should_lock = request.POST.get('lock', True) in [True, 'True', '1', 'on', 'true']
    result = room.join_and_lock(request.user, password=password, lock=should_lock)
    if type(result) is ValidationError:
        return JsonResponse({'status': result.message}, status=400)
    else:
        return JsonResponse({'status': 'ok'})


@login_required
@require_http_methods(['POST'])
def unlock(request):
    zosia = get_object_or_404(Zosia, active=True)
    room = get_object_or_404(UserRoom, user=request.user).room
    if not zosia.is_rooming_open:
        return JsonResponse({'status': 'time_passed'}, status=400)
    result = room.unlock(request.user)
    if result:
        return JsonResponse({'status': 'ok'})
    else:
        return JsonResponse({'status': 'not_changed'})


# https://docs.djangoproject.com/en/1.11/howto/outputting-csv/
# NOTE: Might not be the best approach - consider using csv module instead
def csv_response(data, template, filename='file'):
    response = HttpResponse(content_type='text/csv')
    response['Content-Disposition'] = 'attachment; filename="{}.csv"'.format(filename)
    t = loader.get_template(template)
    c = Context({
        'data': data,
    })
    response.write(t.render(c))
    return response


@staff_member_required
@require_http_methods(['GET'])
def report(request):
    zosia = get_object_or_404(Zosia, active=True)
    rooms = Room.objects.all_visible().prefetch_related('members').all()
    rooms = sorted(rooms, key=lambda x: str(x))
    users = UserPreferences.objects.for_zosia(zosia).prefetch_related('user').all()
    users = sorted(users, key=lambda x: str(x))
    ctx = {
        'zosia': zosia,
        'rooms': rooms,
        'user_preferences': users
    }

    download = request.GET.get('download', False)
    if download == 'users':
        return csv_response(users, template='rooms/users.txt', filename='users')
    if download == 'rooms':
        return csv_response(rooms, template='rooms/rooms.txt', filename='rooms')

    return render(request, 'rooms/report.html', ctx)


def handle_uploaded_file(csvfile):
    rooms = []
    for row in csv.reader(csvfile, delimiter=','):
        name, desc, cap, hidden = row
        if name != "Name":
            rooms.append(
                Room(name=name, description=desc, capacity=cap, hidden=hidden))
    Room.objects.bulk_create(rooms)


@staff_member_required
@require_http_methods(['GET', 'POST'])
def import_room(request):
    zosia = get_object_or_404(Zosia, active=True)
    if request.method == 'POST':
        form = UploadFileForm(request.POST, request.FILES)
        if form.is_valid():
            handle_uploaded_file(TextIOWrapper(request.FILES['file'].file,
                                               encoding=request.encoding))
            return HttpResponseRedirect(reverse('rooms_report'))
    else:
        form = UploadFileForm()
    return render(request, 'rooms/import.html', {'form': form})
