# Painel de Comando MTZ

Central de Alta Performance, Telemetria em Tempo Real, Otimizacao de Hardware e Tweaks Oficiais para Windows 10 e Windows 11.

![Windows 10/11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?logo=windows)
![4K Ready](https://img.shields.io/badge/Resolution-4K%20UHD%20Ready-red)
![Version](https://img.shields.io/badge/Version-3.7.1%20Pro-green)
![License](https://img.shields.io/badge/License-Proprietary%20%2F%20MTZ-black)

---

## Download Direto (Versao Mais Recente)

| Arquivo | Descricao | Download |
| :--- | :--- | :--- |
| **MathzControlPanel.exe** | Executavel unico standalone (Instalador silencioso automatico) | [Baixar EXE Direto](https://raw.githubusercontent.com/Mathzvinicius/MathzControlPanel/main/MathzControlPanel.exe) |
| **MathzControlPanel-v3.0.zip** | Pacote ZIP portatil completo | [Baixar Pacote ZIP](https://raw.githubusercontent.com/Mathzvinicius/MathzControlPanel/main/MathzControlPanel-v3.0.zip) |

---

## Principais Recursos da Versao 3.7.1 Pro

* **Suite de Armazenamento Integrada (CrystalDiskMark & CrystalDiskInfo):**
  * **Mathz Disk Bench (Direct I/O):** Benchmark com testes de Leitura e Escrita Sequencial (SEQ1M Q8T1) e Aleatoria (RND4K Q32T1 e Q1T1) sem distorcao por cache do Windows.
  * **Leitor S.M.A.R.T. Profundo:** Leitura de temperatura operacional, saude do disco (%), horas de uso, contagem de ciclos e status tecnico de unidades NVMe, SATA e HDDs.
  * **Exportacao de Relatorio:** Exportacao instantanea de diagnostico em formato texto.

* **Central Termica de Sensores em Tempo Real:**
  * Monitoramento continuo de temperaturas: **Processador (CPU Package/Tctl/ACPI)**, **Placa de Video (GPU Core/VRAM)** e **Discos de Armazenamento (NVMe/SATA)**.
  * Indicador de estabilidade termica com alertas visuais configuraveis (75Â°C, 80Â°C e 85Â°C).

* **Zero Mouse Delay & Raw Input 1:1 Seguro:**
  * Desativacao completa de aceleracao angular (*Enhanced Pointer Precision OFF*).
  * Injecao da curva linear **MarkC 1:1** com sensibilidade 6/11 nativa (1.0x pixel-perfeito).
  * **Protecao de Clique Duplo (v3.7.1):** Preserva rigorosamente a tolerancia nativa de 4x4 pixels (`DoubleClickWidth = 4`, `DoubleClickHeight = 4`, `DoubleClickSpeed = 500ms`) e corrige o descritor `SPI_SETMOUSE` para evitar bloqueios na Area de Trabalho e pastas.
  * Suporte total a mouses de alta taxa de sondagem (1000Hz, 4000Hz, 8000Hz) e touchpads sem travamento.

* **Telemetria Vetorial & Desempenho:**
  * Grafico vetorial de onda e barras para uso de Processador e Memoria RAM.
  * Liberador de Memoria RAM em 1-clique via API do Windows (`EmptyWorkingSet`).
  * Modos de energia comutaveis instantaneamente: **Maximo Desempenho (100% Unlocked)**, **Equilibrio** e **Frio Silencioso**.

* **Otimizacoes de Baixa Latencia do Sistema (Base da ISO):**
  * Agendamento de GPU acelerado por hardware (**HAGS**) e Modo de Jogo.
  * Prioridade alta de CPU e I/O de disco para emuladores e jogos competitivos (IFEO).
  * Otimizacao de latencia de rede TCP (`TcpAckFrequency = 1` e `TCPNoDelay = 1`).
  * Ajustes de Kernel e BCDedit (`disabledynamictick Yes` e `tscsyncpolicy Enhanced`).
  * Verificacao fidedigna de cada recurso com alerta em tempo real.

* **Interface Ultra HD 4K Ready:**
  * Desenvolvida em WPF com renderizacao vetorial de alta nitidez.
  * Suporte Per-Monitor DPI V2 (100%, 125%, 150%, 200% sem borroes).
  * Tipografia esportiva moderna com temas selecionaveis.

* **Auto-Update Integrado:**
  * Verificacao automatica de atualizacoes diretamente pelo repositorio oficial no GitHub com download e instalacao em 1 clique.

---

## Como Instalar e Executar

1. Baixe o arquivo **[MathzControlPanel.exe](https://raw.githubusercontent.com/Mathzvinicius/MathzControlPanel/main/MathzControlPanel.exe)**.
2. Execute como **Administrador** (o sistema solicitara elevacao automaticamente).
3. O painel se auto-configura, cria o atalho oficial na sua Area de Trabalho e no Menu Iniciar.

---

### 2026 MTZ Performance. Todos os direitos reservados.