let rawData = null;
let chartInstance = null;

// Palette de couleurs harmonieuses pour les courbes
const COLORS = [
    '#4285f4', // Bleu GCP
    '#34d399', // Vert
    '#fbbf24', // Jaune
    '#f87171', // Rouge
    '#a78bfa', // Violet
    '#60a5fa', // Bleu clair
    '#fb7185', // Rose
    '#fb923c'  // Orange
];

document.addEventListener('DOMContentLoaded', () => {
    // Écouteurs d'événements sur les filtres
    document.getElementById('filter-region').addEventListener('change', updateUI);
    document.getElementById('filter-machine').addEventListener('change', updateUI);
    document.getElementById('filter-range').addEventListener('change', updateUI);

    fetchData();
});

async function fetchData() {
    showLoading(true);
    showError(false);

    const urls = ['data.json', 'data.mock.json'];
    let fetched = false;

    for (const url of urls) {
        try {
            logging(`Tentative de récupération de ${url}...`);
            const response = await fetch(url);
            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            
            rawData = await response.json();
            fetched = true;
            logging(`Données récupérées avec succès de ${url}.`);
            break; // Sort de la boucle si succès
        } catch (e) {
            logging(`Échec de récupération de ${url}: ${e.message}`);
        }
    }

    if (!fetched) {
        showLoading(false);
        showError(true);
        return;
    }

    // Mettre à jour l'indicateur temporel de mise à jour
    if (rawData.last_updated) {
        const updateDate = new Date(rawData.last_updated);
        document.getElementById('update-time').textContent = `Mis à jour le : ${updateDate.toLocaleString()}`;
    }

    // Mettre à jour dynamiquement le lien d'exploration BigQuery
    if (rawData.project_id && rawData.dataset_id) {
        const bqLink = document.getElementById('bq-explorer-link');
        const bqText = document.getElementById('bq-explorer-text');
        if (bqLink && bqText) {
            bqLink.href = `https://console.cloud.google.com/bigquery?project=${rawData.project_id}&p=${rawData.project_id}&d=${rawData.dataset_id}&page=dataset`;
            bqText.textContent = `Explorer dans BigQuery (${rawData.dataset_id})`;
        }
    }

    // Initialiser les dropdowns de filtres
    populateFilters();
    
    // Rendre l'interface utilisateur
    showLoading(false);
    updateUI();
}

function populateFilters() {
    const regionSelect = document.getElementById('filter-region');
    const machineSelect = document.getElementById('filter-machine');

    // Récupérer les valeurs uniques
    const regions = new Set();
    const machines = new Set();

    rawData.series.forEach(s => {
        if (s.region) regions.add(s.region);
        if (s.machine_type) machines.add(s.machine_type);
    });

    // Reset dropdowns tout en gardant l'option "Toutes"
    regionSelect.innerHTML = '<option value="all">Toutes les régions</option>';
    machineSelect.innerHTML = '<option value="all">Tous les types</option>';

    // Ajouter les options
    Array.from(regions).sort().forEach(r => {
        const opt = document.createElement('option');
        opt.value = r;
        opt.textContent = r;
        regionSelect.appendChild(opt);
    });

    Array.from(machines).sort().forEach(m => {
        const opt = document.createElement('option');
        opt.value = m;
        opt.textContent = m;
        machineSelect.appendChild(opt);
    });
}

function updateUI() {
    if (!rawData) return;

    const selectedRegion = document.getElementById('filter-region').value;
    const selectedMachine = document.getElementById('filter-machine').value;
    const selectedRangeDays = parseInt(document.getElementById('filter-range').value, 10);

    const now = new Date();
    const cutoffDate = new Date(now.getTime() - (selectedRangeDays * 24 * 60 * 60 * 1000));

    // 1. Filtrer les séries de données
    const filteredSeries = [];
    
    rawData.series.forEach(s => {
        const regionMatch = (selectedRegion === 'all' || s.region === selectedRegion);
        const machineMatch = (selectedMachine === 'all' || s.machine_type === selectedMachine);

        if (regionMatch && machineMatch) {
            // Filtrer la liste temporelle par date
            const filteredData = s.data.filter(d => new Date(d.timestamp) >= cutoffDate);
            
            if (filteredData.length > 0) {
                // Trier par date pour être sûr
                filteredData.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
                
                filteredSeries.push({
                    region: s.region,
                    zone: s.zone || 'ALL',
                    machine_type: s.machine_type,
                    data: filteredData
                });
            }
        }
    });

    // 2. Mettre à jour les KPIs
    calculateKPIs(filteredSeries);

    // 3. Dessiner le graphique
    renderChart(filteredSeries);
}

function calculateKPIs(seriesList) {
    let totalScore = 0;
    let totalUptime = 0;
    let count = 0;
    
    let currentScore = null;
    let last24hScore = null;

    seriesList.forEach(s => {
        const data = s.data;
        if (data.length > 0) {
            // Dernier point disponible
            const latest = data[data.length - 1];
            totalScore += latest.score;
            totalUptime += latest.uptime;
            count++;

            // Calcul de la tendance (différence de score sur 24 heures)
            currentScore = latest.score;
            // Trouver le point le plus proche d'il y a 24h
            const oneDayAgo = new Date(new Date(latest.timestamp).getTime() - (24 * 60 * 60 * 1000));
            const pastPoint = data.find(d => new Date(d.timestamp) >= oneDayAgo);
            if (pastPoint) {
                last24hScore = pastPoint.score;
            }
        }
    });

    const avgScoreEl = document.querySelector('#kpi-score .kpi-value');
    const avgUptimeEl = document.querySelector('#kpi-uptime .kpi-value');
    const trendEl = document.querySelector('#kpi-trend .kpi-value');

    if (count > 0) {
        const avgScore = (totalScore / count).toFixed(2);
        avgScoreEl.textContent = avgScore;
        const avgUptimeValue = totalUptime / count;
        if (avgUptimeValue < 0.1) {
            avgUptimeEl.textContent = `${(avgUptimeValue * 24).toFixed(1)} h`;
        } else {
            avgUptimeEl.textContent = `${avgUptimeValue.toFixed(1)} j`;
        }

        // Style selon le score
        if (avgScore >= 0.7) {
            avgScoreEl.style.color = 'var(--success-green)';
        } else if (avgScore >= 0.4) {
            avgScoreEl.style.color = 'var(--text-primary)';
        } else {
            avgScoreEl.style.color = 'var(--danger-red)';
        }

        // Tendance 24h
        if (currentScore !== null && last24hScore !== null) {
            const diff = currentScore - last24hScore;
            if (diff > 0.05) {
                trendEl.textContent = `↗ Stable/Hausse`;
                trendEl.style.color = 'var(--success-green)';
            } else if (diff < -0.05) {
                trendEl.textContent = `↘ En Baisse`;
                trendEl.style.color = 'var(--danger-red)';
            } else {
                trendEl.textContent = `→ Constant`;
                trendEl.style.color = 'var(--text-secondary)';
            }
        } else {
            trendEl.textContent = 'Stable';
            trendEl.style.color = 'var(--text-secondary)';
        }
    } else {
        avgScoreEl.textContent = '--';
        avgUptimeEl.textContent = '--';
        trendEl.textContent = '--';
        avgScoreEl.style.color = 'var(--text-primary)';
        trendEl.style.color = 'var(--text-primary)';
    }
}

function renderChart(seriesList) {
    const ctx = document.getElementById('capacity-chart').getContext('2d');

    if (chartInstance) {
        chartInstance.destroy();
    }

    // Transformer notre structure en structures attendues par Chart.js
    const datasets = seriesList.map((s, index) => {
        const label = `${s.region} (${s.zone}) - ${s.machine_type}`;
        const color = COLORS[index % COLORS.length];

        return {
            label: label,
            data: s.data.map(d => ({
                x: new Date(d.timestamp),
                y: d.score
            })),
            borderColor: color,
            backgroundColor: color + '15', // Transparent
            borderWidth: 2,
            tension: 0.2, // Légère courbe
            pointRadius: 3,
            pointHoverRadius: 6
        };
    });

    chartInstance = new Chart(ctx, {
        type: 'line',
        data: { datasets },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
                mode: 'index',
                intersect: false
            },
            plugins: {
                legend: {
                    position: 'top',
                    labels: {
                        color: '#9ca3af',
                        font: { family: 'Outfit' }
                    }
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            return ` ${context.dataset.label}: ${context.raw.y.toFixed(2)}`;
                        }
                    }
                }
            },
            scales: {
                x: {
                    type: 'time',
                    time: {
                        tooltipFormat: 'dd MMM yyyy HH:mm',
                        displayFormats: {
                            hour: 'HH:mm',
                            day: 'dd MMM'
                        }
                    },
                    grid: { color: '#374151' },
                    ticks: {
                        color: '#9ca3af',
                        font: { family: 'Outfit' }
                    }
                },
                y: {
                    min: 0,
                    max: 1,
                    grid: { color: '#374151' },
                    ticks: {
                        color: '#9ca3af',
                        font: { family: 'Outfit' }
                    },
                    title: {
                        display: true,
                        text: 'Score d\'obtention (0.0 à 1.0)',
                        color: '#9ca3af',
                        font: { family: 'Outfit', weight: 500 }
                    }
                }
            }
        }
    });
}

function showLoading(show) {
    const el = document.getElementById('loading-state');
    if (show) el.classList.remove('hidden');
    else el.classList.add('hidden');
}

function showError(show) {
    const el = document.getElementById('error-state');
    if (show) el.classList.remove('hidden');
    else el.classList.add('hidden');
}

function logging(msg) {
    console.log(`[CapacityTracker] ${msg}`);
}
