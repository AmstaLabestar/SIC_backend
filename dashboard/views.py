import csv
from django.http import HttpResponse
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.admin.views.decorators import staff_member_required
from django.views.decorators.http import require_POST
from django.core.paginator import Paginator
from django.db.models import Sum, Count
from django.utils import timezone
from datetime import timedelta
from django.contrib import messages
from django.contrib.auth import authenticate, login as auth_login, logout as auth_logout
from core.models import Agent, Transaction, Report, ActivityLog
from core.utils import log_activity

def login_view(request):
    if request.user.is_authenticated and request.user.is_staff:
        return redirect('dashboard:dashboard_home')
        
    if request.method == 'POST':
        u = request.POST.get('username')
        p = request.POST.get('password')
        next_url = request.POST.get('next', 'dashboard:dashboard_home')
        
        user = authenticate(request, username=u, password=p)
        if user is not None and user.is_staff:
            auth_login(request, user)
            log_activity(
                user=user,
                action="ADMIN_LOGIN",
                description=f"Connexion réussie du Super Administrateur ({user.username}).",
                level="INFO",
                ip_address=request.META.get('REMOTE_ADDR')
            )
            if next_url and next_url != 'None' and next_url.startswith('/'):
                return redirect(next_url)
            return redirect('dashboard:dashboard_home')
        else:
            log_activity(
                action="LOGIN_FAILED",
                description=f"Tentative de connexion échouée pour l'utilisateur: {u}",
                level="WARNING",
                ip_address=request.META.get('REMOTE_ADDR')
            )
            messages.error(request, "Identifiants invalides ou accès refusé.")
            
    return render(request, 'dashboard/login.html')

def logout_view(request):
    auth_logout(request)
    return redirect('dashboard:login')

@staff_member_required(login_url='dashboard:login')
def home(request):
    import json
    from django.db.models.functions import TruncDate, TruncWeek, TruncMonth
    from django.contrib.auth.models import User

    total_agents = Agent.objects.count()
    pending_kyc = Agent.objects.filter(kyc_status='PENDING').count()

    # Base aggregated data
    transactions_agg = Transaction.objects.filter(status='COMPLETED').aggregate(
        total_volume=Sum('amount'),
        total_count=Count('id'),
        total_profit=Sum('commission_sic')
    )

    now = timezone.now()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week_start = today_start - timedelta(days=now.weekday())
    month_start = today_start.replace(day=1)

    profit_today = Transaction.objects.filter(status='COMPLETED', created_at__gte=today_start).aggregate(Sum('commission_sic'))['commission_sic__sum'] or 0
    profit_week = Transaction.objects.filter(status='COMPLETED', created_at__gte=week_start).aggregate(Sum('commission_sic'))['commission_sic__sum'] or 0
    profit_month = Transaction.objects.filter(status='COMPLETED', created_at__gte=month_start).aggregate(Sum('commission_sic'))['commission_sic__sum'] or 0

    # Profit by Operator
    operator_profits = Transaction.objects.filter(status='COMPLETED').values('target_operator').annotate(profit=Sum('commission_sic')).order_by('-profit')

    # =========================================================================
    # STATISTIQUES UTILISATEURS (inscriptions par jour/semaine/mois)
    # =========================================================================

    # Utilisateurs par jour (30 derniers jours)
    thirty_days_ago = today_start - timedelta(days=30)
    users_per_day = (
        Agent.objects.filter(created_at__gte=thirty_days_ago)
        .annotate(date=TruncDate('created_at'))
        .values('date')
        .annotate(count=Count('id'))
        .order_by('date')
    )

    # Utilisateurs par semaine (12 dernières semaines)
    twelve_weeks_ago = today_start - timedelta(weeks=12)
    users_per_week = (
        Agent.objects.filter(created_at__gte=twelve_weeks_ago)
        .annotate(week=TruncWeek('created_at'))
        .values('week')
        .annotate(count=Count('id'))
        .order_by('week')
    )

    # Utilisateurs par mois (12 derniers mois)
    twelve_months_ago = today_start - timedelta(days=365)
    users_per_month = (
        Agent.objects.filter(created_at__gte=twelve_months_ago)
        .annotate(month=TruncMonth('created_at'))
        .values('month')
        .annotate(count=Count('id'))
        .order_by('month')
    )

    # Totaux utilisateurs par période
    agents_today = Agent.objects.filter(created_at__gte=today_start).count()
    agents_this_week = Agent.objects.filter(created_at__gte=week_start).count()
    agents_this_month = Agent.objects.filter(created_at__gte=month_start).count()

    # =========================================================================
    # MONTANTS ÉCHANGÉS par jour/semaine/mois
    # =========================================================================

    # Montants par jour (30 derniers jours)
    volume_per_day = (
        Transaction.objects.filter(status='COMPLETED', created_at__gte=thirty_days_ago)
        .annotate(date=TruncDate('created_at'))
        .values('date')
        .annotate(total=Sum('amount'), count=Count('id'))
        .order_by('date')
    )

    # Montants par semaine (12 dernières semaines)
    volume_per_week = (
        Transaction.objects.filter(status='COMPLETED', created_at__gte=twelve_weeks_ago)
        .annotate(week=TruncWeek('created_at'))
        .values('week')
        .annotate(total=Sum('amount'), count=Count('id'))
        .order_by('week')
    )

    # Montants par mois (12 derniers mois)
    volume_per_month = (
        Transaction.objects.filter(status='COMPLETED', created_at__gte=twelve_months_ago)
        .annotate(month=TruncMonth('created_at'))
        .values('month')
        .annotate(total=Sum('amount'), count=Count('id'))
        .order_by('month')
    )

    # Totaux montants par période
    volume_today = Transaction.objects.filter(status='COMPLETED', created_at__gte=today_start).aggregate(total=Sum('amount'))['total'] or 0
    volume_this_week = Transaction.objects.filter(status='COMPLETED', created_at__gte=week_start).aggregate(total=Sum('amount'))['total'] or 0
    volume_this_month = Transaction.objects.filter(status='COMPLETED', created_at__gte=month_start).aggregate(total=Sum('amount'))['total'] or 0
    tx_count_today = Transaction.objects.filter(status='COMPLETED', created_at__gte=today_start).count()
    tx_count_week = Transaction.objects.filter(status='COMPLETED', created_at__gte=week_start).count()
    tx_count_month = Transaction.objects.filter(status='COMPLETED', created_at__gte=month_start).count()

    # =========================================================================
    # Préparer les données JSON pour les graphiques Chart.js
    # =========================================================================

    # Données utilisateurs par jour
    chart_users_daily_labels = [entry['date'].strftime('%d/%m') for entry in users_per_day]
    chart_users_daily_data = [entry['count'] for entry in users_per_day]

    # Données utilisateurs par semaine
    chart_users_weekly_labels = [entry['week'].strftime('%d/%m') for entry in users_per_week]
    chart_users_weekly_data = [entry['count'] for entry in users_per_week]

    # Données utilisateurs par mois
    chart_users_monthly_labels = [entry['month'].strftime('%b %Y') for entry in users_per_month]
    chart_users_monthly_data = [entry['count'] for entry in users_per_month]

    # Données volumes par jour
    chart_volume_daily_labels = [entry['date'].strftime('%d/%m') for entry in volume_per_day]
    chart_volume_daily_data = [float(entry['total']) for entry in volume_per_day]

    # Données volumes par semaine
    chart_volume_weekly_labels = [entry['week'].strftime('%d/%m') for entry in volume_per_week]
    chart_volume_weekly_data = [float(entry['total']) for entry in volume_per_week]

    # Données volumes par mois
    chart_volume_monthly_labels = [entry['month'].strftime('%b %Y') for entry in volume_per_month]
    chart_volume_monthly_data = [float(entry['total']) for entry in volume_per_month]

    context = {
        'total_agents': total_agents,
        'pending_kyc': pending_kyc,
        'total_volume': transactions_agg['total_volume'] or 0,
        'total_transactions': transactions_agg['total_count'] or 0,
        'total_profit': transactions_agg['total_profit'] or 0,
        'profit_today': profit_today,
        'profit_week': profit_week,
        'profit_month': profit_month,
        'operator_profits': operator_profits,
        # Stats utilisateurs
        'agents_today': agents_today,
        'agents_this_week': agents_this_week,
        'agents_this_month': agents_this_month,
        # Stats volumes
        'volume_today': volume_today,
        'volume_this_week': volume_this_week,
        'volume_this_month': volume_this_month,
        'tx_count_today': tx_count_today,
        'tx_count_week': tx_count_week,
        'tx_count_month': tx_count_month,
        # Données graphiques JSON
        'chart_users_daily_labels': json.dumps(chart_users_daily_labels),
        'chart_users_daily_data': json.dumps(chart_users_daily_data),
        'chart_users_weekly_labels': json.dumps(chart_users_weekly_labels),
        'chart_users_weekly_data': json.dumps(chart_users_weekly_data),
        'chart_users_monthly_labels': json.dumps(chart_users_monthly_labels),
        'chart_users_monthly_data': json.dumps(chart_users_monthly_data),
        'chart_volume_daily_labels': json.dumps(chart_volume_daily_labels),
        'chart_volume_daily_data': json.dumps(chart_volume_daily_data),
        'chart_volume_weekly_labels': json.dumps(chart_volume_weekly_labels),
        'chart_volume_weekly_data': json.dumps(chart_volume_weekly_data),
        'chart_volume_monthly_labels': json.dumps(chart_volume_monthly_labels),
        'chart_volume_monthly_data': json.dumps(chart_volume_monthly_data),
    }
    return render(request, 'dashboard/home.html', context)

@staff_member_required(login_url='dashboard:login')
def agents(request):
    from django.db.models import Q
    agent_list = Agent.objects.all().order_by('-created_at')
    
    search_query = request.GET.get('search')
    if search_query:
        agent_list = agent_list.filter(
            Q(first_name__icontains=search_query) | 
            Q(last_name__icontains=search_query) | 
            Q(phone_number__icontains=search_query)
        )
        
    status_filter = request.GET.get('status')
    if status_filter:
        agent_list = agent_list.filter(kyc_status=status_filter)
        
    paginator = Paginator(agent_list, 20)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    return render(request, 'dashboard/agents.html', {
        'page_obj': page_obj,
        'search_query': search_query,
        'status_filter': status_filter
    })

@staff_member_required(login_url='dashboard:login')
def transactions(request, tx_type=None):
    if tx_type:
        # Convert url friendly type to uppercase database value (e.g. 'depots' -> 'DEPOT')
        if tx_type == 'conversions':
            db_type = 'SWAP'
            page_title = "Historique des Conversions"
        else:
            db_type = tx_type.upper().rstrip('S')
            page_title = f"Historique des {tx_type.capitalize()}"
        transaction_list = Transaction.objects.filter(type=db_type).order_by('-created_at')
    else:
        transaction_list = Transaction.objects.all().order_by('-created_at')
        page_title = "Historique des Transactions"
        
    # Apply operator filter if present
    operator_filter = request.GET.get('operator')
    if operator_filter:
        transaction_list = transaction_list.filter(target_operator=operator_filter)
        page_title += f" ({operator_filter})"

    # Apply status filter if present
    status_filter = request.GET.get('status')
    if status_filter:
        transaction_list = transaction_list.filter(status=status_filter)

    if request.GET.get('export') == 'csv':
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="transactions_{tx_type or "all"}_{timezone.now().strftime("%Y%m%d")}.csv"'
        
        writer = csv.writer(response)
        writer.writerow(['ID', 'Date', 'Agent', 'Type', 'Opérateur', 'Numéro cible', 'Montant', 'Commission SIC', 'Statut'])
        for tx in transaction_list:
            agent_name = f"{tx.agent.first_name} {tx.agent.last_name}" if tx.agent else "N/A"
            writer.writerow([tx.id, tx.created_at.strftime('%Y-%m-%d %H:%M:%S'), agent_name, tx.type, tx.target_operator, tx.target_phone_number, tx.amount, tx.commission_sic, tx.status])
        
        log_activity(user=request.user, action="EXPORT_CSV", description=f"Export CSV des transactions ({tx_type or 'toutes'}) généré.", level="INFO")
        return response
        
    paginator = Paginator(transaction_list, 50)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    return render(request, 'dashboard/transactions.html', {
        'page_obj': page_obj, 
        'page_title': page_title, 
        'tx_type': tx_type,
        'operator_filter': operator_filter,
        'status_filter': status_filter
    })

@staff_member_required(login_url='dashboard:login')
def transaction_detail(request, tx_id):
    tx = get_object_or_404(Transaction, id=tx_id)
    return render(request, 'dashboard/transaction_detail.html', {'transaction': tx})

@require_POST
@staff_member_required(login_url='dashboard:login')
def agent_kyc_action(request, agent_id, action):
    agent = get_object_or_404(Agent, id=agent_id)
    if action == 'approve':
        agent.kyc_status = 'APPROVED'
        # Monter le palier KYC (pilote les plafonds) : palier demandé sinon
        # complet (2) par défaut, cohérent avec l'API /auth/kyc/review/ (lot C3).
        agent.kyc_tier = agent.kyc_requested_tier or max(agent.kyc_tier, 2)
        agent.kyc_requested_tier = None
        agent.kyc_rejection_reason = ''
        messages.success(request, f"L'agent {agent.first_name} a été approuvé.")
        log_activity(user=request.user, agent=agent, action="KYC_APPROVED", description=f"Le compte KYC de l'agent {agent.phone_number} a été approuvé.", level="SUCCESS")
    elif action == 'reject':
        agent.kyc_status = 'REJECTED'
        messages.warning(request, f"Le KYC de l'agent {agent.first_name} a été rejeté.")
        log_activity(user=request.user, agent=agent, action="KYC_REJECTED", description=f"Le dossier KYC de l'agent {agent.phone_number} a été rejeté.", level="ERROR")
    elif action == 'suspend':
        agent.is_suspended = not agent.is_suspended
        status_msg = "suspendu" if agent.is_suspended else "réactivé"
        messages.info(request, f"L'agent {agent.first_name} a été {status_msg}.")
        log_activity(user=request.user, agent=agent, action="KYC_SUSPENDED", description=f"Le compte de l'agent {agent.phone_number} a été {status_msg}.", level="WARNING")
    
    agent.save()
    return redirect('dashboard:agents')

@staff_member_required(login_url='dashboard:login')
def report_list(request):
    reports = Report.objects.all().order_by('-created_at')
    return render(request, 'dashboard/reports_list.html', {'reports': reports})

@staff_member_required(login_url='dashboard:login')
def report_create(request, report_id=None):
    report = get_object_or_404(Report, id=report_id) if report_id else None
    
    if request.method == 'POST':
        title = request.POST.get('title')
        date_range = request.POST.get('date_range', 'ALL')
        tx_type = request.POST.get('tx_type', 'ALL')
        operator = request.POST.get('operator', 'ALL')
        status = request.POST.get('status', 'ALL')
        
        if report:
            report.title = title
            report.date_range = date_range
            report.tx_type = tx_type
            report.operator = operator
            report.status = status
            report.save()
            messages.success(request, f"Le rapport '{report.title}' a été mis à jour.")
            log_activity(user=request.user, action="REPORT_UPDATED", description=f"Mise à jour du rapport: {report.title}")
        else:
            report = Report.objects.create(
                title=title, date_range=date_range, tx_type=tx_type,
                operator=operator, status=status, created_by=request.user
            )
            messages.success(request, f"Le rapport '{report.title}' a été créé.")
            log_activity(user=request.user, action="REPORT_CREATED", description=f"Création d'un nouveau rapport: {report.title}", level="SUCCESS")
            
        return redirect('dashboard:report_list')
        
    return render(request, 'dashboard/report_form.html', {'report': report})

@staff_member_required(login_url='dashboard:login')
def report_detail(request, report_id):
    report = get_object_or_404(Report, id=report_id)
    transactions = Transaction.objects.all()
    
    # Apply Filters
    if report.tx_type != 'ALL':
        transactions = transactions.filter(type=report.tx_type)
    if report.operator != 'ALL':
        transactions = transactions.filter(target_operator=report.operator)
    if report.status != 'ALL':
        transactions = transactions.filter(status=report.status)
        
    if report.date_range != 'ALL':
        now = timezone.now()
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        if report.date_range == 'TODAY':
            transactions = transactions.filter(created_at__gte=today_start)
        elif report.date_range == 'THIS_WEEK':
            week_start = today_start - timedelta(days=now.weekday())
            transactions = transactions.filter(created_at__gte=week_start)
        elif report.date_range == 'THIS_MONTH':
            month_start = today_start.replace(day=1)
            transactions = transactions.filter(created_at__gte=month_start)
            
    transactions = transactions.order_by('-created_at')
    
    if request.GET.get('export') == 'csv':
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="rapport_{report.id}_{timezone.now().strftime("%Y%m%d")}.csv"'
        
        writer = csv.writer(response)
        writer.writerow(['ID', 'Date', 'Agent', 'Type', 'Opérateur', 'Numéro cible', 'Montant', 'Commission SIC', 'Statut'])
        for tx in transactions:
            agent_name = f"{tx.agent.first_name} {tx.agent.last_name}" if tx.agent else "N/A"
            writer.writerow([tx.id, tx.created_at.strftime('%Y-%m-%d %H:%M:%S'), agent_name, tx.type, tx.target_operator, tx.target_phone_number, tx.amount, tx.commission_sic, tx.status])
            
        log_activity(user=request.user, action="EXPORT_CSV_REPORT", description=f"Export CSV généré pour le rapport '{report.title}'.", level="INFO")
        return response
    
    # Aggregations
    agg = transactions.aggregate(
        total_volume=Sum('amount'),
        total_profit=Sum('commission_sic')
    )
    
    context = {
        'report': report,
        'transactions': transactions[:100], # Limit to 100 for display
        'total_volume': agg['total_volume'] or 0,
        'total_profit': agg['total_profit'] or 0,
        'total_count': transactions.count()
    }
    return render(request, 'dashboard/report_detail.html', context)

@require_POST
@staff_member_required(login_url='dashboard:login')
def report_delete(request, report_id):
    report = get_object_or_404(Report, id=report_id)
    report.delete()
    messages.success(request, f"Le rapport a été supprimé.")
    return redirect('dashboard:report_list')

@staff_member_required(login_url='dashboard:login')
def activity_logs(request):
    logs_list = ActivityLog.objects.all().order_by('-created_at')
    
    # Optional filtering
    level_filter = request.GET.get('level')
    if level_filter:
        logs_list = logs_list.filter(level=level_filter)
        
    paginator = Paginator(logs_list, 50)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    return render(request, 'dashboard/activity_logs.html', {'page_obj': page_obj})
