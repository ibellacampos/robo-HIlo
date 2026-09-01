//+------------------------------------------------------------------+
//|                                                        Robot.mq5 |
//|                     Copyright 2024, Todos os direitos reservados |
//+------------------------------------------------------------------+

#property copyright      "Copyright 2024, Todos os direitos reservados"
#property version        "4.00"
#property description    "AO PERMITIR ALGO TRADING, VOCÊ DECLARA TER LIDO"
#property description    "E CONCORDA COM OS TERMOS DE USO DO ROBÔ"
#property description    "ORION EDGE PRO | NUCLEO ORIGINAL PRESERVADO"
#property description    "Mercados: B3 e Forex | Conta: NET e HEDGE"
#property description    "Por se tratar de um software de meio e não de resultado,"
#property description    "todas as operações realizadas, os consequentes resultados financeiros"
#property description    "e potenciais perdas do capital investido são de responsabilidade exclusiva"
#property description    "do investidor, que detém o poder de configuração e parametrização,"
#property description    "sendo responsável pela tomada de decisão."

//+------------------------------------------------------------------+
//| INCLUDES O1                                                      |
//+------------------------------------------------------------------+

  #include <Controls\Defines.mqh>

//+------------------------------------------------------------------+
//| DEFINES                                                          |
//+------------------------------------------------------------------+

  #undef  CONTROLS_DIALOG_COLOR_BG
  #undef  CONTROLS_DIALOG_COLOR_CLIENT_BG
  #undef  CONTROLS_FONT_NAME
  #undef  CONTROLS_BORDER_WIDTH
  #undef  CONTROLS_DIALOG_COLOR_CAPTION_TEXT
  #undef  CONTROLS_DIALOG_CAPTION_HEIGHT
  #undef  CONTROLS_DIALOG_MINIMIZE_WIDTH
  #undef  CONTROLS_DIALOG_MINIMIZE_HEIGHT
  #undef  CONTROLS_DIALOG_COLOR_BORDER_LIGHT
  #undef  CONTROLS_DIALOG_COLOR_BORDER_DARK
  #undef  CONTROLS_FONT_SIZE
  #undef  ON_APP_CLOSE
  #define CONTROLS_DIALOG_COLOR_BG            clrBlack
  #define CONTROLS_DIALOG_COLOR_CLIENT_BG     C'10,15,20'
  #define CONTROLS_FONT_NAME                  "Consolas"
  #define CONTROLS_BORDER_WIDTH               (4)
  #define CONTROLS_DIALOG_COLOR_CAPTION_TEXT  clrWhite
  #define CONTROLS_DIALOG_CAPTION_HEIGHT      (30)
  #define CONTROLS_DIALOG_MINIMIZE_WIDTH      (400)
  #define CONTROLS_DIALOG_MINIMIZE_HEIGHT     (5*CONTROLS_BORDER_WIDTH+CONTROLS_DIALOG_CAPTION_HEIGHT)
  #define CONTROLS_DIALOG_COLOR_BORDER_LIGHT  C'28,195,170'
  #define CONTROLS_DIALOG_COLOR_BORDER_DARK   C'28,195,170'
  #define CONTROLS_FONT_SIZE                  (8)
  #define ON_APP_CLOSE                        (0)

//+------------------------------------------------------------------+
//| INCLUDES O2                                                      |
//+------------------------------------------------------------------+

  #include <Controls\Dialog.mqh>
  #include <Controls\Label.mqh>
  #include <Controls\Panel.mqh>
  #include <Controls\Button.mqh>

//+------------------------------------------------------------------+
//| INCLUDES O3                                                      |
//+------------------------------------------------------------------+

  #include <Trade\PositionInfo.mqh>
  #include <Trade\Trade.mqh>
  #include <Trade\SymbolInfo.mqh>
  #include <Trade\AccountInfo.mqh>
  #include <Trade\OrderInfo.mqh>
  #resource "\\Indicators\\BB-Madyson.ex5"
  #resource "\\Indicators\\MediaMovel.ex5"
  #resource "\\Indicators\\MT5_MM_Points.ex5"
  // Nexus_Zonas_11, VPRangev6, SupportResistanceRejectionPro e ShowTrades NÃO são
  // embutidos via #resource: são indicadores de terceiros que o compilador rejeita
  // ao tentar reprocessá-los como recurso embutido (erro de compilação). Em vez
  // disso são carregados em tempo de execução via iCustom(), exigindo que os .ex5
  // estejam fisicamente em MQL5\Indicators\ no terminal onde o robô rodar.

//---

CPositionInfo         m_position;                   // Objeto de posição comercial
CTrade                m_trade;                      // Objeto de negociação
CSymbolInfo           m_symbol;                     // Objeto de informação de símbolo
CAccountInfo          m_account;                    // account info wrapper

//+------------------------------------------------------------------+
//| LIGADO E DESLIGADO                                               |
//+------------------------------------------------------------------+

  enum ENUM_HAB
  {
    Ligado,     // [00] Ligado
    Desligado   // [01] Desligado
  };

//+------------------------------------------------------------------+
//| ENUMERADOR PARA SIM E NÃO                                        |
//+------------------------------------------------------------------+

  enum ENUM_SIM_NAO
  {
    sim,  // [00] Sim
    nao   // [01] Não
  };

//+------------------------------------------------------------------+
//| ESCOLHA O TEMPO GRÁFICO                                          |
//+------------------------------------------------------------------+

  enum ENUM_TEMPO_GRAFICO
  {
    timeframe_corrente = PERIOD_CURRENT,  // [Período Corrente]
    timeframe_01_min   = PERIOD_M1,       // [Gráfico de 1 Minuto]
    timeframe_02_min   = PERIOD_M2,       // [Gráfico de 2 Minutos]
    timeframe_03_min   = PERIOD_M3,       // [Gráfico de 3 Minutos]
    timeframe_04_min   = PERIOD_M4,       // [Gráfico de 4 Minutos]
    timeframe_05_min   = PERIOD_M5,       // [Gráfico de 5 Minutos]
    timeframe_06_min   = PERIOD_M6,       // [Gráfico de 6 Minutos]
    timeframe_10_min   = PERIOD_M10,      // [Gráfico de 10 Minutos]
    timeframe_12_min   = PERIOD_M12,      // [Gráfico de 12 Minutos]
    timeframe_15_min   = PERIOD_M15,      // [Gráfico de 15 Minutos]
    timeframe_20_min   = PERIOD_M20,      // [Gráfico de 20 Minutos]
    timeframe_30_min   = PERIOD_M30,      // [Gráfico de 30 Minutos]
    timeframe_1_hora   = PERIOD_H1,       // [Gráfico de 1 Hora]
    timeframe_2_horas  = PERIOD_H2,       // [Gráfico de 2 Horas]
    timeframe_3_horas  = PERIOD_H3,       // [Gráfico de 3 Horas]
    timeframe_4_horas  = PERIOD_H4,       // [Gráfico de 4 Horas]
    timeframe_6_horas  = PERIOD_H6,       // [Gráfico de 6 Horas]
    timeframe_8_horas  = PERIOD_H8,       // [Gráfico de 8 Horas]
    timeframe_12_horas = PERIOD_H12,      // [Gráfico de 12 Horas]
    timeframe_1_dia    = PERIOD_D1,       // [Gráfico de 1 Dia]
    timeframe_1_semana = PERIOD_W1,       // [Gráfico de 1 Semana]
    timeframe_1_mes    = PERIOD_MN1       // [Gráfico de 1 Mês]
  };

//+------------------------------------------------------------------+
//| ENUMERADOR DE ESCALAS DO GRÁFICO                                 |
//+------------------------------------------------------------------+

  enum ENUM_ESCALA
  {
    um     = 1,  // 1
    dois   = 2,  // 2
    tres   = 3,  // 3
    quatro = 4,  // 4
    cinco  = 5   // 5
  };

//+------------------------------------------------------------------+
//| ENUMERADOR DE TIPO DE ENTRADA - AUMENTOS DE POSIÇÃO              |
//+------------------------------------------------------------------+

  enum ENUM_AUMENTOS
  {
    mercado,  // [00] A Mercado
    pedra     // [01] Na Pedra
  };

//+------------------------------------------------------------------+
//| ENUMERADOR DE ESTRATÉGIAS                                        |
//+------------------------------------------------------------------+

  enum ENUM_ESTRATEGIA
  {
    estrategia_price_action,              // [00] Price Action
    estrategia_cruzamento_de_medias,      // [01] Cruzamento De Duas Médias
    estrategia_bb,                        // [02] Bandas de Bollinger
    estrategia_afastamento_de_media,      // [03] Afastamento de Média
    estrategia_virada_hilo,               // [04] Virada de HiLo
    estrategia_nexus_zonas,               // [05] Nexus Zonas
    estrategia_vprange,                   // [06] VPRange (Volume Profile)
    estrategia_sr_rejection               // [07] Support Resistance Rejection Pro
  };

//+------------------------------------------------------------------+
//| ENUMERADOR DE TENDÊNCIA                                          |
//+------------------------------------------------------------------+

  enum ENUM_TENDENCIA
  {
    a_favor_da_tendencia,    // [00] A Favor da Tendência
    contra_a_tendencia       // [01] Contra a Tendência
  };

//+------------------------------------------------------------------+
//| ENUMERADOR DE CONFIRMAÇÃO                                        |
//+------------------------------------------------------------------+

  enum ENUM_CONFIRMACAO
  {
    sem_confirmacao,    // [00] Sem Confirmação
    com_confirmacao     // [01] Com Confirmação
  };

//+------------------------------------------------------------------+
//| PARÂMETROS DO ROBÔ                                               |
//+------------------------------------------------------------------+

input group                    "---> CONFIGURAÇÕES GERAIS"
input string                   config01;                                               // ---> GERAL
input ENUM_ESTRATEGIA          estrategia = estrategia_virada_hilo;                   // [00] Estratégia
input ENUM_TEMPO_GRAFICO       tempoGrafico = timeframe_05_min;                        // [01] Tempo Gráfico
input ulong                    m_magic = 13;                                            // [02] Número Mágico [Máx. 2 dígitos]
input ENUM_SIM_NAO             points_ = nao;                                          // [03] Conversão para Points
input double                   InpLot = 1;                                             // [04] Contratos
input double                   InpTakeProfit = 2000.0;                                    // [05] TakeProfit em Pontos
input double                   InpStopLoss = 220.0;                                      // [06] StopLoss em Pontos
input int                      tradesPorDia = 0;                                       // [07] Qtd. de trades por dia
input string                   config02;                                               // ---> HORÁRIO DE FUNCIONAMENTO
input ENUM_HAB                 escolheHabilitarRelogio = Ligado;                       // [00] Relógio das Operações
input string                   hora_inicio = "09:35";                                  // [01] Horário de Início das Entradas
input string                   hora_fim = "17:28";                                     // [02] Horário de Encerramento das Entradas
input string                   hora_zeragem = "17:30";                                 // [03] Horário de Zeragem

input group                    "---> PRICE ACTION"
input ENUM_TENDENCIA           tendenciaPriceAction = a_favor_da_tendencia;            // [00] Tendência
input double                   tamanhoMaximoDaVela = 0.0;                              // [01] Tamanho Mínimo da Vela
input double                   pontosRompimento = 0.0;                                 // [02] Qtd. de pontos para rompimento

input group                    "---> BANDAS DE BOLLINGER"
input ENUM_TENDENCIA           tendenciaBB = a_favor_da_tendencia;                     // [00] Tendência
input int                      bb_bands_period = 20;                                   // [01] Período
input int                      bb_bands_shift = 0;                                     // [02] Deslocamento
input double                   bb_deviation = 2.0;                                     // [03] Desvio
input ENUM_APPLIED_PRICE       bb_applied_price = PRICE_CLOSE;                         // [04] Preço
input color                    bb_InpColorBBSuperior = clrBlue;                        // [05] Cor da Banda Superior
input int                      bb_InpWidthBBSuperior = 2;                              // [06] Espessura da Banda Superior
input color                    bb_InpColorBBCentral = clrBlack;                        // [07] Cor da Banda Central
input int                      bb_InpWidthBBCentral = 2;                               // [08] Espessura da Banda Central
input color                    bb_InpColorBBInferior = clrBlue;                        // [09] Cor da Banda Inferior
input int                      bb_InpWidthBBInferior = 2;                              // [10] Espessura da Banda Inferior

input group                    "---> CRUZAMENTO DE DUAS MÉDIAS"
input string                   op01;                                                   // ➱ CONFIRMAÇÃO
input ENUM_CONFIRMACAO         confirmacaoCM = com_confirmacao;                        // [00] Com ou Sem Confirmação
input string                   op02;                                                   // ➱ MÉDIA CURTA
input int                      MM01_ma_period = 8;                                     // [00] Período
input int                      MM01_ma_shift = 0;                                      // [01] Deslocamento
input ENUM_MA_METHOD            MM01_ma_method = MODE_EMA;                              // [02] Método
input ENUM_APPLIED_PRICE       MM01_applied_price = PRICE_CLOSE;                       // [03] Preço
input color                    MM01_InpColor = clrDodgerBlue;                          // [04] Cor
input int                      MM01_espessura = 2;                                     // [05] Espessura
input string                   op03;                                                   // ➱ MÉDIA LONGA
input int                      MM02_ma_period = 21;                                    // [00] Período
input int                      MM02_ma_shift = 0;                                      // [01] Deslocamento
input ENUM_MA_METHOD            MM02_ma_method = MODE_EMA;                              // [02] Método
input ENUM_APPLIED_PRICE       MM02_applied_price = PRICE_CLOSE;                       // [03] Preço
input color                    MM02_InpColor = clrBlack;                               // [04] Cor
input int                      MM02_espessura = 2;                                     // [05] Espessura

input group                    "---> AFASTAMENTO DE MÉDIA"
input ENUM_TENDENCIA           tendenciaAfastamento = a_favor_da_tendencia;            // [00] Tendência
input ENUM_SIM_NAO             pointsAfastamento = nao;                                // [01] Conversão para Points
input int                      InpMAPeriod = 7;                                        // [02] Período
input int                      InpMAShift = 0;                                         // [03] Deslocamento
input ENUM_MA_METHOD            InpMAMethod = MODE_EMA;                                 // [04] Método
input double                   InpLevelUp = 100;                                       // [05] DX Superior
input double                   InpLevelDown = -100;                                    // [06] DX Inferior
string                         InpName = "Para DX  '0' utilize 1 ou -1";               // [07] Observações da parametrização
input color                    InpColorDXCima = clrBlue;                               // [07] Cor da Linha Superior
input int                      espessuraDXCima = 1;                                    // [08] Espessura da Linha Superior
input color                    InpColorMediaMovel = clrBlack;                          // [09] Cor da Linha Central
input int                      espessuraMediaMovel = 2;                                // [10] Espessura da Linha Central
input color                    InpColorDXBaixo = clrBlue;                              // [11] Cor da Linha Inferior
input int                      espessuraDXBaixo = 1;                                   // [12] Espessura da Linha Inferior

input group                    "---> VIRADA DE HILO ACTIVATOR"
input string                   hilo01;                                                  // ➱ SINAL / ENTRADA
input ENUM_CONFIRMACAO         confirmacaoHiLo = com_confirmacao;                       // [00] Confirmar virada no fechamento
input int                      InpPeriodHilo = 13;                                      // [01] Período [SET: 13]
input ENUM_MA_METHOD            InpMethodHilo = MODE_LWMA;                               // [02] Método [SET: 3 = LWMA]
input string                   hilo02;                                                  // ➱ VISUAL DO INDICADOR
input ENUM_SIM_NAO             exibirHiLoNoGrafico = sim;                               // [03] Exibir HiLo no gráfico
input int                      barrasHistoricoHiLo = 300;                               // [04] Barras desenhadas
input color                    corCompraHilo = C'30,144,255';                           // [05] Cor Compra [SET: 16748574]
input int                      espessuraCompraHilo = 3;                                 // [06] Espessura Compra [SET: 3]
input color                    corVendaHilo = C'255,69,0';                              // [07] Cor Venda [SET: 17919]
input int                      espessuraVendaHilo = 3;                                  // [08] Espessura Venda [SET: 3]
input string                   hilo03;                                                  // ➱ SAÍDA
input ENUM_SIM_NAO             encerrarOperacaoHilo = sim;                              // [09] Encerrar operação na virada contrária [SET: 1]

input group                    "---> NEXUS ZONAS"
input ENUM_TENDENCIA           tendenciaNexusZonas = a_favor_da_tendencia;             // [00] Tendência
input ENUM_CONFIRMACAO         confirmacaoNexusZonas = com_confirmacao;                // [01] Confirmar sinal no fechamento

input group                    "---> VPRANGE (VOLUME PROFILE)"
input ENUM_TENDENCIA           tendenciaVPRange = a_favor_da_tendencia;                // [00] Tendência
input ENUM_CONFIRMACAO         confirmacaoVPRange = com_confirmacao;                   // [01] Confirmar sinal no fechamento

input group                    "---> SUPPORT RESISTANCE REJECTION PRO"
input ENUM_TENDENCIA           tendenciaSRRejection = a_favor_da_tendencia;            // [00] Tendência
input ENUM_CONFIRMACAO         confirmacaoSRRejection = com_confirmacao;               // [01] Confirmar sinal no fechamento

input group                    "---> SHOWTRADES [VISUAL]"
input ENUM_HAB                 exibirShowTrades = Ligado;                              // [00] Exibir indicador de negociações no gráfico

input group                    "---> BREAKEVEN"
input double                   Break_Even_Start = 230.0;                                 // [00] Breakeven Start ["0" ➝ não usar]
input double                   Break_Even_Step = 0.0;                                  // [01] Breakeven Step ["0" ➝ não usar]

input group                    "---> TRAILLING STOP [BE > 0]"
input double                   Trailing_Start = 0.0;                                   // [00] Trailling Start ["0" ➝ não usar]
input double                   Trailing_Step = 0.0;                                    // [01] Trailling Step ["0" ➝ não usar]

input group                    "---> REENTRADAS | CONTRA"
input ENUM_HAB                 ligarAumentosParaTras = Desligado;                      // [00] Ligado/Desligado
input ENUM_AUMENTOS            tipoDeOPeracaoAumento = mercado;                        // [01] Tipo de Reentradas
input string                   aumentoParaTras = "100, 200, 300";                      // [02] Distância
input string                   volumeAumentoParaTras = "1, 2, 3";                      // [03] Contratos
input string                   stopGainAumentoParaTras = "500, 400, 100";              // [04] TP do Preço Médio]

input group                    "---> SAÍDAS PARCIAIS"
input ENUM_HAB                 ligarRealizacoesParciais = Desligado;                   // [00] Ligado/Desligado
input string                   pontosRealizacao = "100, 200, 300";                     // [01] Distância
input string                   volumeDaParcial = "1, 2, 3";                            // [02] Contratos

input group                    "---> METAS FINANCEIRAS"
input double                   meta_diaria_lucro = 0.0;                                // [00] Meta de Lucro Diário ["0" -> não usar]
input double                   meta_diaria_prejuizo = 0.0;                             // [01] Meta de Prejuízo Diário ["0" -> não usar]
input double                   meta_operacao_lucro = 0.0;                              // [02] Meta de Lucro da Operação ["0" ➝ não usar]
input double                   meta_operacao_prejuizo = 0.0;                           // [03] Meta de Prejuízo da Operação ["0" ➝ não usar]
input ENUM_HAB                 ligarMetas = Ligado;                                    // [04] Séries Contínuas
input string                   letras = "WIN";                                         // [05] Três Primeiras Letras do Ativo

input group                    "---> PROPRIEDADES DO GRÁFICO"
input ENUM_ESCALA              escalaDoGrafico = cinco;                                // [00] Escala
input bool                     gradeDoGrafico = false;                                 // [01] Grade
input color                    corDaGradeDoGrafico = clrNONE;                          // [02] Cor da Grade
input bool                     linhaAskDoGrafico = true;                               // [03] Linha Ask
input color                    corDaLinhaAsk = C'28,195,170';                                // [04] Cor da Linha Ask
input bool                     linhaBidDoGrafico = true;                               // [05] Linha Bid
input color                    corDaLinhaBid = C'255,96,96';                                 // [06] Cor da Linha Bid
input bool                     linhaLastDoGrafico = true;                              // [07] Linha do Último Preço
input color                    corDaLinhaLast = C'201,211,220';                              // [08] Cor da Linha do Último Preço
input color                    corDoPrimeiroPlano = C'218,226,232';                          // [09] Cor do Primeiro Plano
input color                    corDoFundoDoGrafico = C'7,11,16';                         // [10] Cor do Fundo do Gráfico
input color                    corDoCandleDeAlta = C'28,195,170';                           // [11] Cor do Candle de Alta
input color                    corDaBarraDeAlta = C'28,195,170';                            // [12] Cor da Barra de Alta
input color                    corDoCandleDeBaixa = C'255,96,96';                            // [13] Cor do Candle de Baixa
input color                    corDaBarraDeBaixa = C'255,96,96';                           // [14] Cor da Barra de Baixa
input ENUM_SIM_NAO             setasAtrasDoGrafico = nao;                              // [15] Setas da Operação atrás do gráfico

input group                    "---> PAINEL GRÁFICO"
input string                   panelTitulo = "ORION EDGE PRO | ORIGINAL CORE";                  // [00] Título do painel
input int                      panelWidth = 350;                                       // [01] Largura do Painel
input int                      panelHeight = 380;                                      // [02] Altura do Painel
input int                      panelLarguraTexto01 = 10;                               // [03] Posição Horizontal da Coluna 01
input int                      panelLarguraTexto02 = 200;                              // [04] Posição Horizontal da Coluna 02
input int                      panelAlturaTexto = 15;                                  // [05] Distância Vertical do Texto
input int                      posicaoHorizontalBotaoResetar = 10;                     // [06] Posição horizontal do botão
input int                      posicaoVerticalBotaoResetar = 260;                      // [07] Posição vertical do botão
input int                      larguraBotaoResetar = 320;                              // [08] Largura do botão
input int                      alturaBotaoResetar = 320;                               // [09] Altura do botão

//+------------------------------------------------------------------+
//| VARIÁVEIS GLOBAIS                                                |
//+------------------------------------------------------------------+

string                         hoje = "";
datetime                       hora_atual = 0;
double                         meta_batida = 0.0;
MqlRates                       candle[];
MqlRates                       candleSemana[];
datetime                       diaAtual = 0;
bool                           ordPendente = false;
double                         porcentagemAcertos = 0.0;
int                            trades_positivos = 0;
double                         porcentagemAcertos_mes = 0.0;
int                            trades_positivos_mes = 0;
double                         porcentagemAcertos_semana = 0.0;
int                            trades_positivos_semana = 0;
bool                           posicaoAberta = false;
string                         metaDiaria = "Não Batida";
double                         precoDeEntradaOperacao = 0.0;
double                         takeProfitOperacao = 0.0;
double                         stopLossOperacao = 0.0;
double                         volumeOperacao = 0.0;
int                            posicoesAbertas = 0;
ulong                          ticketOperacao = 0;
string                         comentario = "";
bool                           comprado = false;
bool                           vendido = false;
double                         lucroPosicoes = 0.0;
double                         volumeDaPosicaoAberta = 0.0;
string                         posicaoAtual = "";
double                         hoje_ = 0.0;
bool                           novaBarra = false;
double                         pos_price = 0.0;
double                         pos_price_semana = 0.0;
double                         pos_price_mes = 0.0;
int                            pos_trades = 0;
int                            pos_trades_semana = 0;
int                            pos_trades_mes = 0;
bool                           candle_operado = false;
double                         ExtInpStopLoss = 0.0;
double                         ExtInpTakeProfit = 0.0;
double                         ExtBreakEvenStart = 0.0;
double                         ExtBreakEvenStep = 0.0;
double                         ExtTraillingStart = 0.0;
double                         ExtTraillingStep = 0.0;
double                         ExtTamanhoMaximoDaVela = 0.0;
double                         ExtPontosRompimento = 0.0;
double                         precoMedio = 0.0;
double                         precoDeEntradaRE = 0;
datetime                       data_e_hora_ultima_entrada = 0;
bool                           criarLinhasSP = false;
int                            quantidadeDeTrades = 0.0;
ENUM_ORDER_TYPE_TIME           tipoDeOrdem = ENUM_ORDER_TYPE_TIME(ORDER_TIME_DAY);
int                            handleBB = INVALID_HANDLE;
int                            handleMM01 = INVALID_HANDLE;
int                            handleMM02 = INVALID_HANDLE;
int                            handleAfastamento = INVALID_HANDLE;
int                            handleHiLoHigh = INVALID_HANDLE;
int                            handleHiLoLow = INVALID_HANDLE;
int                            handleNexusZonas = INVALID_HANDLE;
int                            handleVPRange = INVALID_HANDLE;
int                            handleSRRejection = INVALID_HANDLE;
int                            handleShowTrades = INVALID_HANDLE;
double                         bufferBBSuperior[];
double                         bufferBBInferior[];
double                         bufferMM01[];
double                         bufferMM02[];
double                         bufferAfastamentoCentral[];
double                         bufferAfastamentoSuperior[];
double                         bufferAfastamentoInferior[];
double                         bufferHiLoHigh[];
double                         bufferHiLoLow[];
double                         bufferNexusZonasCompra[];
double                         bufferNexusZonasVenda[];
double                         bufferVPRangeCompra[];
double                         bufferVPRangeVenda[];
double                         bufferSRRejectionCompra[];
double                         bufferSRRejectionVenda[];
CAppDialog                     m_panel;
CLabel                         m_Texto01;
CLabel                         m_Texto02;
CLabel                         m_Texto03;
CLabel                         m_Texto04;
CLabel                         m_Texto05;
CLabel                         m_Texto06;
CLabel                         m_Texto07;
CLabel                         m_Texto08;
CLabel                         m_Texto09;
CLabel                         m_Texto10;
CLabel                         m_Texto11;
CLabel                         m_Texto12;
CLabel                         m_Texto13;
CLabel                         m_Texto14;
CLabel                         m_Texto15;
CLabel                         m_Texto16;
CLabel                         m_Texto17;
CLabel                         m_Texto18;
CLabel                         m_Texto19;
CLabel                         m_Texto20;
CLabel                         m_Texto21;
CLabel                         m_Texto22;
CLabel                         m_Texto23;
CLabel                         m_Texto24;
CLabel                         m_Texto25;
CLabel                         m_Texto26;
CLabel                         m_Texto27;
CLabel                         m_Texto28;
CLabel                         m_Texto29;
CLabel                         m_Texto30;
CButton                        m_button01;
string                         dataHora = "2050.12.31 23:59:59";  // Vitalícia = 2050.12.31 23:59:59

//+------------------------------------------------------------------+
//| FUNÇÃO ON INIT                                                   |
//+------------------------------------------------------------------+

int OnInit()
  {

//+------------------------------------------------------------------+
//| CONTA DEMO                                                       |
//+------------------------------------------------------------------+
/*
   ENUM_ACCOUNT_TRADE_MODE tradeMode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);

   if(tradeMode == ACCOUNT_TRADE_MODE_REAL)
   {
     Alert(__FUNCTION__,": Robot -> Licença somente para conta DEMO");
     return(INIT_FAILED);
   }
*/
//+------------------------------------------------------------------+
//| CONTA REAL                                                       |
//+------------------------------------------------------------------+
/*
   long account01     = 958463;                   // Account login 01

   ENUM_ACCOUNT_TRADE_MODE tradeMode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);

   if(tradeMode == ACCOUNT_TRADE_MODE_REAL && AccountInfoInteger(ACCOUNT_LOGIN) != account01)
   {
      Alert(__FUNCTION__,": Robot -> Login não autorizado");
      return(INIT_FAILED);
   }
*/
//+------------------------------------------------------------------+
//| RESET LAST ERROR                                                 |
//+------------------------------------------------------------------+

  ResetLastError();

//+------------------------------------------------------------------+
//| ATUALIZA OS DADOS DO SÍMBOLO                                     |
//+------------------------------------------------------------------+

   m_symbol.Name(_Symbol);
   m_symbol.Refresh();

//+------------------------------------------------------------------+
//| Verificar se existem posições abertas                            |
//+------------------------------------------------------------------+

  bool posiAberta = false;

  for(int i = PositionsTotal()-1; i>=0; i--)
  {
     ulong posTicket = PositionGetTicket(i);

     if(PositionSelectByTicket(posTicket))
     {
        string symbol = PositionGetString(POSITION_SYMBOL);
        ulong magic = PositionGetInteger(POSITION_MAGIC);

        if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && symbol == _Symbol)
        {
           posiAberta = true;
           break;
        }
     }
  }

//+------------------------------------------------------------------+
//| VALIDADE DO ROBÔ                                                 |
//+------------------------------------------------------------------+

  if(string(TimeCurrent()) > dataHora)
  {
    Alert(__FUNCTION__,": Robot -> Licença Expirada em: "+dataHora);
    if(!posiAberta) return(INIT_FAILED);
  }

//+------------------------------------------------------------------+
//| VERIFICA O LOTE                                                  |
//+------------------------------------------------------------------+

   string err_text="";

   if(!CheckVolumeValue(InpLot,err_text))
   {
      Alert("Robot -> O volume está incorreto. ");
      if(!posiAberta) return(INIT_PARAMETERS_INCORRECT);
   }

   //--- SAÍDAS PARCIAIS

   string valuesVolumeParcial[];
   int retVolumeParcial = StringSplit(volumeDaParcial,',',valuesVolumeParcial);
   string valuesPontosParcial[];
   int retPontosParcial = StringSplit(pontosRealizacao,',',valuesPontosParcial);

   if(ligarRealizacoesParciais == Ligado && retVolumeParcial != retPontosParcial)
   {
     Alert("Robot -> As saídas parciais não apresentam a mesma quantidade de valores! ");
     if(!posiAberta) return(INIT_PARAMETERS_INCORRECT);
   }

   if(retVolumeParcial > 0 && ligarRealizacoesParciais == Ligado)
   {
      for(int i = 0; i < retVolumeParcial; i++)
      {
        if(!CheckVolumeValue(StringToDouble(valuesVolumeParcial[i]),err_text))
        {
          Alert("Robot -> O volume da saída parcial " + IntegerToString(i+1) + " está incorreto. ");
          if(!posiAberta) return(INIT_PARAMETERS_INCORRECT);
        }
      }
   }

   //--- AUMENTOS DE POSIÇÃO PARA TRÁS

   string valuesDistanciaAumentosParaTras[];
   string valuesVolumeAumentosParaTras[];
   string valuesTPAumentosParaTras[];

   int retDistanciaAumentosParaTras = StringSplit(aumentoParaTras,',',valuesDistanciaAumentosParaTras);
   int retVolumeAumentosParaTras = StringSplit(volumeAumentoParaTras,',',valuesVolumeAumentosParaTras);
   int retTPAumentosParaTras = StringSplit(stopGainAumentoParaTras,',',valuesTPAumentosParaTras);

   if(ligarAumentosParaTras == Ligado && (retDistanciaAumentosParaTras != retVolumeAumentosParaTras
      || retDistanciaAumentosParaTras != retTPAumentosParaTras || retVolumeAumentosParaTras != retTPAumentosParaTras))
   {
     Alert("Robot -> Os aumentos de posição contra a operação não apresentam a mesma quantidade de valores! ");
     if(!posiAberta) return(INIT_PARAMETERS_INCORRECT);
   }

   if(retVolumeAumentosParaTras > 0 && ligarAumentosParaTras == Ligado)
   {
      for(int i = 0; i < retVolumeAumentosParaTras; i++)
      {
        if(!CheckVolumeValue(StringToDouble(valuesVolumeAumentosParaTras[i]),err_text))
        {
          Alert("Robot -> O volume da Reentrada " + IntegerToString(i+1) + " está incorreto. ");
          if(!posiAberta) return(INIT_PARAMETERS_INCORRECT);
        }
      }
   }

//+------------------------------------------------------------------+
//| TIPO DE CONTA                                                    |
//+------------------------------------------------------------------+

   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_NETTING && AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
     Alert(IntegerToString(AccountInfoInteger(ACCOUNT_MARGIN_MODE)),": Robot -> Este EA só funciona nas contas NET e HEDGE.");
     if(!posiAberta) return(INIT_FAILED);
   }

//+------------------------------------------------------------------+
//| DEFINIR TEMPLATE PARA O GRÁFICO                                  |
//+------------------------------------------------------------------+

  ChartDefines(0, 0);
  ChartModeSet(CHART_CANDLES ,0);
  ChartScaleSet(escalaDoGrafico,0);

//+------------------------------------------------------------------+
//| VELOCIDADE EM QUE A ORDEM VAI À CORRETORA                        |
//+------------------------------------------------------------------+

   PrintFormat("ÚLTIMO PING=%.f ms",
               TerminalInfoInteger(TERMINAL_PING_LAST)/1000.);

//+------------------------------------------------------------+
//| VERIFICA SE O PREJUÍZO MÁXIMO DO DIA É UM NÚMERO NEGATIVO  |
//+------------------------------------------------------------+

   if(meta_diaria_prejuizo < 0)
   {
     Alert("Robot -> O parâmetro Prejuízo Máximo do Dia deve ser um número positivo");
     if(!posiAberta) return(INIT_PARAMETERS_INCORRECT);
   }

//+-----------------------------------------------------------------+
//| QUANTIDADE DE DIGITOS DO NÚMERO MÁGICO                          |
//+-----------------------------------------------------------------+

  if(StringLen(string(m_magic)) > 2)
  {
    Alert("Robot -> A quantidade de dígitos do número mágico não pode ser maior do que 2. ");
    if(!posiAberta) return(INIT_PARAMETERS_INCORRECT);
  }

//+-----------------------------------------------------------------+
//| QUANTIDADE DE CARACTERES DO ATIVO - METAS FINANCEIRAS           |
//+-----------------------------------------------------------------+

  if(StringLen(letras) > 3)
  {
    Alert("Robot -> A quantidade de caracteres do Ativo não pode ser maior do que 3. ");
    if(!posiAberta) return(INIT_PARAMETERS_INCORRECT);
  }

//+------------------------------------------------------------------+
//| VOLUME IGUAL A 0                                                 |
//+------------------------------------------------------------------+

  if(InpLot == 0)
  {
    Alert("Robot -> O volume não pode ser igual a 0.");
    if(!posiAberta) return(INIT_PARAMETERS_INCORRECT);
  }

//+------------------------------------------------------------------+
//| FILLING DAS ORDENS, SLIPPAGE E OUTROS PARÂMETROS                 |
//+------------------------------------------------------------------+

   m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
   m_trade.SetMarginMode();
   m_trade.SetAsyncMode(false);
   m_trade.SetExpertMagicNumber(m_magic);

//+------------------------------------------------------------------+
//| CRIAÇÃO DO INDICADOR BANDAS DE BOLLINGER                         |
//+------------------------------------------------------------------+

   if(estrategia == estrategia_bb)
   {
      handleBB = iCustom(_Symbol, ENUM_TIMEFRAMES(tempoGrafico), "::Indicators\\BB-Madyson.ex5", bb_bands_period, bb_bands_shift, bb_deviation, bb_applied_price, bb_InpColorBBSuperior, bb_InpWidthBBSuperior, bb_InpColorBBCentral, bb_InpWidthBBCentral, bb_InpColorBBInferior, bb_InpWidthBBInferior);
      if(handleBB == INVALID_HANDLE)
      {
         PrintFormat("Robot -> Falha ao criar o identificador do indicador BANDAS DE BOLLINGER para o símbolo %s/%s, erro código %d",
                     Symbol(),
                     EnumToString(ENUM_TIMEFRAMES(tempoGrafico)),
                     GetLastError());
         if(!posiAberta) return(INIT_FAILED);
      }

      if(!ArraySetAsSeries(bufferBBSuperior, true)){Print("Robot -> Falha no ArraySetAsSeries do indicador BANDAS DE BOLLINGER", GetLastError()); if(!posiAberta) return(INIT_FAILED);}
      if(!ArraySetAsSeries(bufferBBInferior, true)){Print("Robot -> Falha no ArraySetAsSeries do indicador BANDAS DE BOLLINGER", GetLastError()); if(!posiAberta) return(INIT_FAILED);}
   }

//+------------------------------------------------------------------+
//| CRIAÇÃO DO INDICADOR MÉDIA - CRUZAMENTO DE DUAS MÉDIAS MÓVEIS    |
//+------------------------------------------------------------------+

   if(estrategia == estrategia_cruzamento_de_medias)
   {
      //+------------------------------------------------------------------+
      //| MÉDIA 01                                                         |
      //+------------------------------------------------------------------+

         handleMM01 = iCustom(_Symbol, ENUM_TIMEFRAMES(tempoGrafico), "::Indicators\\MediaMovel.ex5", MM01_ma_period, MM01_ma_shift, MM01_ma_method, MM01_applied_price, MM01_InpColor, MM01_espessura);
         if(handleMM01 == INVALID_HANDLE)
         {
            PrintFormat("Robot -> Falha ao criar o identificador do indicador MÉDIA MÓVEL 01 para o símbolo %s/%s, erro código %d",
                        Symbol(),
                        EnumToString(ENUM_TIMEFRAMES(tempoGrafico)),
                        GetLastError());
            if(!posiAberta) return(INIT_FAILED);
         }

         if(!ArraySetAsSeries(bufferMM01, true)){Print("Robot -> Falha no ArraySetAsSeries do indicador MÉDIA MÓVEL 01", GetLastError()); if(!posiAberta) return(INIT_FAILED);}

      //+------------------------------------------------------------------+
      //| MÉDIA 02                                                         |
      //+------------------------------------------------------------------+

         handleMM02 = iCustom(_Symbol, ENUM_TIMEFRAMES(tempoGrafico), "::Indicators\\MediaMovel.ex5", MM02_ma_period, MM02_ma_shift, MM02_ma_method, MM02_applied_price, MM02_InpColor, MM02_espessura);
         if(handleMM02 == INVALID_HANDLE)
         {
            PrintFormat("Robot -> Falha ao criar o identificador do indicador MÉDIA MÓVEL 02 para o símbolo %s/%s, erro código %d",
                        Symbol(),
                        EnumToString(ENUM_TIMEFRAMES(tempoGrafico)),
                        GetLastError());
            if(!posiAberta) return(INIT_FAILED);
         }

         if(!ArraySetAsSeries(bufferMM02, true)){Print("Robot -> Falha no ArraySetAsSeries do indicador MÉDIA MÓVEL 02", GetLastError()); if(!posiAberta) return(INIT_FAILED);}
   }

//+------------------------------------------------------------------+
//| CRIAÇÃO DO INDICADOR AFASTAMENTO DE MÉDIAS                       |
//+------------------------------------------------------------------+

   if(estrategia == estrategia_afastamento_de_media)
   {
      handleAfastamento = iCustom(_Symbol, ENUM_TIMEFRAMES(tempoGrafico), "::Indicators\\MT5_MM_Points.ex5", pointsAfastamento, InpMAPeriod, InpMAShift, InpMAMethod, InpLevelUp, InpLevelDown, InpName, InpColorDXCima, espessuraDXCima, InpColorMediaMovel, espessuraMediaMovel, InpColorDXBaixo, espessuraDXBaixo);
      if(handleAfastamento == INVALID_HANDLE)
      {
         PrintFormat("Robot -> Falha ao criar o identificador do indicador AFASTAMENTO DE MÉDIA para o símbolo %s/%s, erro código %d",
                     Symbol(),
                     EnumToString(ENUM_TIMEFRAMES(tempoGrafico)),
                     GetLastError());
         if(!posiAberta) return(INIT_FAILED);
      }

      if(!ArraySetAsSeries(bufferAfastamentoCentral, true)){Print("Robot -> Falha no ArraySetAsSeries do indicador AFASTAMENTO DE MÉDIA", GetLastError()); if(!posiAberta) return(INIT_FAILED);}
      if(!ArraySetAsSeries(bufferAfastamentoInferior, true)){Print("Robot -> Falha no ArraySetAsSeries do indicador AFASTAMENTO DE MÉDIA", GetLastError()); if(!posiAberta) return(INIT_FAILED);}
      if(!ArraySetAsSeries(bufferAfastamentoSuperior, true)){Print("Robot -> Falha no ArraySetAsSeries do indicador AFASTAMENTO DE MÉDIA", GetLastError()); if(!posiAberta) return(INIT_FAILED);}
   }

//+------------------------------------------------------------------+
//| CRIAÇÃO DAS MÉDIAS DO HILO                                       |
//+------------------------------------------------------------------+

   if(estrategia == estrategia_virada_hilo)
   {
      if(InpPeriodHilo < 1)
      {
         Alert("Robot -> O período do HiLo deve ser maior que zero.");
         if(!posiAberta) return(INIT_PARAMETERS_INCORRECT);
      }

      handleHiLoHigh = iMA(_Symbol, ENUM_TIMEFRAMES(tempoGrafico), InpPeriodHilo, 0, InpMethodHilo, PRICE_HIGH);
      if(handleHiLoHigh == INVALID_HANDLE)
      {
         PrintFormat("Robot -> Falha ao criar a média das MÁXIMAS do HiLo para %s/%s, erro %d",
                     Symbol(), EnumToString(ENUM_TIMEFRAMES(tempoGrafico)), GetLastError());
         if(!posiAberta) return(INIT_FAILED);
      }

      handleHiLoLow = iMA(_Symbol, ENUM_TIMEFRAMES(tempoGrafico), InpPeriodHilo, 0, InpMethodHilo, PRICE_LOW);
      if(handleHiLoLow == INVALID_HANDLE)
      {
         PrintFormat("Robot -> Falha ao criar a média das MÍNIMAS do HiLo para %s/%s, erro %d",
                     Symbol(), EnumToString(ENUM_TIMEFRAMES(tempoGrafico)), GetLastError());
         if(!posiAberta) return(INIT_FAILED);
      }

      if(!ArraySetAsSeries(bufferHiLoHigh, true))
      {
         Print("Robot -> Falha no ArraySetAsSeries do HiLo High: ", GetLastError());
         if(!posiAberta) return(INIT_FAILED);
      }

      if(!ArraySetAsSeries(bufferHiLoLow, true))
      {
         Print("Robot -> Falha no ArraySetAsSeries do HiLo Low: ", GetLastError());
         if(!posiAberta) return(INIT_FAILED);
      }
   }

//+------------------------------------------------------------------+
//| CRIAÇÃO DO INDICADOR NEXUS ZONAS                                 |
//| ATENÇÃO: indicador de terceiros, carregado com os parâmetros     |
//| padrão dele (não expostos como input do robô). Os buffers 0/1    |
//| são lidos pela CONVENÇÃO 0=seta de compra / 1=seta de venda -    |
//| não confirmada com o código-fonte do indicador. Valide no        |
//| gráfico antes de operar em conta real.                           |
//+------------------------------------------------------------------+

   if(estrategia == estrategia_nexus_zonas)
   {
      handleNexusZonas = iCustom(_Symbol, ENUM_TIMEFRAMES(tempoGrafico), "Nexus_Zonas_11");
      if(handleNexusZonas == INVALID_HANDLE)
      {
         PrintFormat("Robot -> Falha ao criar o identificador do indicador NEXUS ZONAS para o símbolo %s/%s, erro código %d",
                     Symbol(),
                     EnumToString(ENUM_TIMEFRAMES(tempoGrafico)),
                     GetLastError());
         if(!posiAberta) return(INIT_FAILED);
      }

      if(!ArraySetAsSeries(bufferNexusZonasCompra, true)){Print("Robot -> Falha no ArraySetAsSeries do indicador NEXUS ZONAS", GetLastError()); if(!posiAberta) return(INIT_FAILED);}
      if(!ArraySetAsSeries(bufferNexusZonasVenda, true)){Print("Robot -> Falha no ArraySetAsSeries do indicador NEXUS ZONAS", GetLastError()); if(!posiAberta) return(INIT_FAILED);}
   }

//+------------------------------------------------------------------+
//| CRIAÇÃO DO INDICADOR VPRANGE (VOLUME PROFILE)                    |
//| ATENÇÃO: mesma ressalva do NEXUS ZONAS acima.                    |
//+------------------------------------------------------------------+

   if(estrategia == estrategia_vprange)
   {
      handleVPRange = iCustom(_Symbol, ENUM_TIMEFRAMES(tempoGrafico), "VPRangev6");
      if(handleVPRange == INVALID_HANDLE)
      {
         PrintFormat("Robot -> Falha ao criar o identificador do indicador VPRANGE para o símbolo %s/%s, erro código %d",
                     Symbol(),
                     EnumToString(ENUM_TIMEFRAMES(tempoGrafico)),
                     GetLastError());
         if(!posiAberta) return(INIT_FAILED);
      }

      if(!ArraySetAsSeries(bufferVPRangeCompra, true)){Print("Robot -> Falha no ArraySetAsSeries do indicador VPRANGE", GetLastError()); if(!posiAberta) return(INIT_FAILED);}
      if(!ArraySetAsSeries(bufferVPRangeVenda, true)){Print("Robot -> Falha no ArraySetAsSeries do indicador VPRANGE", GetLastError()); if(!posiAberta) return(INIT_FAILED);}
   }

//+------------------------------------------------------------------+
//| CRIAÇÃO DO INDICADOR SUPPORT RESISTANCE REJECTION PRO            |
//| ATENÇÃO: mesma ressalva do NEXUS ZONAS acima.                    |
//+------------------------------------------------------------------+

   if(estrategia == estrategia_sr_rejection)
   {
      handleSRRejection = iCustom(_Symbol, ENUM_TIMEFRAMES(tempoGrafico), "SupportResistanceRejectionPro");
      if(handleSRRejection == INVALID_HANDLE)
      {
         PrintFormat("Robot -> Falha ao criar o identificador do indicador SUPPORT RESISTANCE REJECTION PRO para o símbolo %s/%s, erro código %d",
                     Symbol(),
                     EnumToString(ENUM_TIMEFRAMES(tempoGrafico)),
                     GetLastError());
         if(!posiAberta) return(INIT_FAILED);
      }

      if(!ArraySetAsSeries(bufferSRRejectionCompra, true)){Print("Robot -> Falha no ArraySetAsSeries do indicador SUPPORT RESISTANCE REJECTION PRO", GetLastError()); if(!posiAberta) return(INIT_FAILED);}
      if(!ArraySetAsSeries(bufferSRRejectionVenda, true)){Print("Robot -> Falha no ArraySetAsSeries do indicador SUPPORT RESISTANCE REJECTION PRO", GetLastError()); if(!posiAberta) return(INIT_FAILED);}
   }

//+------------------------------------------------------------------+
//| CRIAÇÃO DO INDICADOR SHOWTRADES [VISUAL]                         |
//| Só desenha o histórico de negociações no gráfico, independente   |
//| da estratégia escolhida - não é lido pelo robô.                  |
//+------------------------------------------------------------------+

   if(exibirShowTrades == Ligado)
   {
      handleShowTrades = iCustom(_Symbol, ENUM_TIMEFRAMES(tempoGrafico), "ShowTrades");
      if(handleShowTrades == INVALID_HANDLE)
         PrintFormat("Robot -> Falha ao criar o identificador do indicador SHOWTRADES para o símbolo %s/%s, erro código %d",
                     Symbol(),
                     EnumToString(ENUM_TIMEFRAMES(tempoGrafico)),
                     GetLastError());
   }

//+------------------------------------------------z-----------------+
//| ADICIONAR INDICADOR NO GRÁFICO                                   |
//+------------------------------------------------------------------+

   //--- REMOVE INDICADORES

   for(int i=0;i<2;i++)
     RemoveIndicadores();

   //--- ADICIONA INDICADORES

   if(estrategia == estrategia_bb)
   {
      if(!ChartIndicatorAdd(0,0,handleBB))
        PrintFormat("Robot -> Falha ao adicionar o indicador BANDAS DE BOLLINGER %d na janela do gráfico. Código de erro %d", GetLastError());
   }

   //---

   if(estrategia == estrategia_cruzamento_de_medias)
   {
      if(!ChartIndicatorAdd(0,0,handleMM01))
        PrintFormat("Robot -> Falha ao adicionar o indicador MÉDIA MÓVEL 01 %d na janela do gráfico. Código de erro %d", GetLastError());

      if(!ChartIndicatorAdd(0,0,handleMM02))
        PrintFormat("Robot -> Falha ao adicionar o indicador MÉDIA MÓVEL 02 %d na janela do gráfico. Código de erro %d", GetLastError());
   }

   //---

   if(estrategia == estrategia_afastamento_de_media)
   {
      if(!ChartIndicatorAdd(0,0,handleAfastamento))
        PrintFormat("Robot -> Falha ao adicionar o indicador AFASTAMENTO DE MÉDIA %d na janela do gráfico. Código de erro %d", GetLastError());
   }

   //---

   if(estrategia == estrategia_nexus_zonas)
   {
      if(!ChartIndicatorAdd(0,0,handleNexusZonas))
        PrintFormat("Robot -> Falha ao adicionar o indicador NEXUS ZONAS %d na janela do gráfico. Código de erro %d", GetLastError());
   }

   //---

   if(estrategia == estrategia_vprange)
   {
      if(!ChartIndicatorAdd(0,0,handleVPRange))
        PrintFormat("Robot -> Falha ao adicionar o indicador VPRANGE %d na janela do gráfico. Código de erro %d", GetLastError());
   }

   //---

   if(estrategia == estrategia_sr_rejection)
   {
      if(!ChartIndicatorAdd(0,0,handleSRRejection))
        PrintFormat("Robot -> Falha ao adicionar o indicador SUPPORT RESISTANCE REJECTION PRO %d na janela do gráfico. Código de erro %d", GetLastError());
   }

   //---

   if(exibirShowTrades == Ligado && handleShowTrades != INVALID_HANDLE)
   {
      if(!ChartIndicatorAdd(0,0,handleShowTrades))
        PrintFormat("Robot -> Falha ao adicionar o indicador SHOWTRADES %d na janela do gráfico. Código de erro %d", GetLastError());
   }

//+------------------------------------------------------------------+
//| CANDLE                                                           |
//+------------------------------------------------------------------+

   if(!ArraySetAsSeries(candle,true)){Print("Robot -> Falha no ArraySetAsSeries do CANDLE", GetLastError()); if(!posiAberta) return(INIT_FAILED);}
   if(!ArraySetAsSeries(candleSemana,true)){Print("Robot -> Falha no ArraySetAsSeries do CANDLE DA SEMANA", GetLastError()); if(!posiAberta) return(INIT_FAILED);}

//+------------------------------------------------------------------+
//| TIRA DAS CORES DOS STOPS                                         |
//+------------------------------------------------------------------+

   ChartSetInteger(0,CHART_COLOR_VOLUME,0,clrNONE);
   ChartSetInteger(0,CHART_COLOR_STOP_LEVEL,0,clrNONE);

//+------------------------------------------------------------------+
//| METAS FINANCEIRAS                                                |
//+------------------------------------------------------------------+

  funcao_verifica_meta_ou_perda_atingida();
  funcao_verifica_meta_ou_perda_atingida_semana();
  funcao_verifica_meta_ou_perda_atingida_mes();

//+------------------------------------------------------------------+
//| CRIAÇÃO DO PAINEL                                                |
//+------------------------------------------------------------------+

   m_panel.Create(0, panelTitulo, 0, 0, 0, panelWidth, panelHeight);

//+------------------------------------------------------------------+
//| CRIAÇÃO DOS TÍTULOS DO PAINEL                                    |
//+------------------------------------------------------------------+

    m_Texto01.Create(NULL, "Texto01: ", 0, panelLarguraTexto01, panelAlturaTexto*1, 1, 1);
    m_Texto01.Text("Ativo:");
    m_Texto01.Color(clrWhite);
    m_panel.Add(m_Texto01);

    m_Texto02.Create(NULL, "Texto02", 0, panelLarguraTexto01, panelAlturaTexto*2, 2, 1);
    m_Texto02.Text("Número Mágico:");
    m_Texto02.Color(clrWhite);
    m_panel.Add(m_Texto02);

    m_Texto03.Create(NULL, "Texto03: ", 0, panelLarguraTexto01, panelAlturaTexto*3, 1, 1);
    m_Texto03.Text("Volume:");
    m_Texto03.Color(clrWhite);
    m_panel.Add(m_Texto03);

    m_Texto04.Create(NULL, "Texto04", 0, panelLarguraTexto01, panelAlturaTexto*4, 1, 1);
    m_Texto04.Text("Data:");
    m_Texto04.Color(clrWhite);
    m_panel.Add(m_Texto04);

    m_Texto05.Create(NULL, "Texto05: ", 0, panelLarguraTexto01, panelAlturaTexto*5, 1, 1);
    m_Texto05.Text("Posição Atual:");
    m_Texto05.Color(clrWhite);
    m_panel.Add(m_Texto05);

    m_Texto06.Create(NULL, "Texto06", 0, panelLarguraTexto01, panelAlturaTexto*6, 1, 1);
    m_Texto06.Text("Hora:");
    m_Texto06.Color(clrWhite);
    m_panel.Add(m_Texto06);

    m_Texto07.Create(NULL, "Texto07: ", 0, panelLarguraTexto01, panelAlturaTexto*7, 1, 1);
    m_Texto07.Text("Acertos do Dia:");
    m_Texto07.Color(clrWhite);
    m_panel.Add(m_Texto07);

    m_Texto08.Create(NULL, "Texto08", 0, panelLarguraTexto01, panelAlturaTexto*8, 1, 1);
    m_Texto08.Text("Acertos da Semana:");
    m_Texto08.Color(clrWhite);
    m_panel.Add(m_Texto08);

    m_Texto09.Create(NULL, "Texto09: ", 0, panelLarguraTexto01, panelAlturaTexto*9, 1, 1);
    m_Texto09.Text("Acertos do Mês:");
    m_Texto09.Color(clrWhite);
    m_panel.Add(m_Texto09);

    m_Texto10.Create(NULL, "Texto10", 0, panelLarguraTexto01, panelAlturaTexto*10, 1, 1);
    m_Texto10.Text("Próx. Candle:");
    m_Texto10.Color(clrWhite);
    m_panel.Add(m_Texto10);

    m_Texto11.Create(NULL, "Texto11: ", 0, panelLarguraTexto01, panelAlturaTexto*11, 1, 1);
    m_Texto11.Text("Meta Diária:");
    m_Texto11.Color(clrWhite);
    m_panel.Add(m_Texto11);

    m_Texto12.Create(NULL, "Texto12: ", 0, panelLarguraTexto01, panelAlturaTexto*12, 1, 1);
    m_Texto12.Text("Lucro da Operação:");
    m_Texto12.Color(clrWhite);
    m_panel.Add(m_Texto12);

    m_Texto13.Create(NULL, "Texto13", 0, panelLarguraTexto01, panelAlturaTexto*13, 1, 1);
    m_Texto13.Text("Lucro do Dia:");
    m_Texto13.Color(clrWhite);
    m_panel.Add(m_Texto13);

    m_Texto14.Create(NULL, "Texto14", 0, panelLarguraTexto01, panelAlturaTexto*14, 1, 1);
    m_Texto14.Text("Lucro da Semana:");
    m_Texto14.Color(clrWhite);
    m_panel.Add(m_Texto14);

    m_Texto15.Create(NULL, "Texto15", 0, panelLarguraTexto01, panelAlturaTexto*15, 1, 1);
    m_Texto15.Text("Lucro do Mês:");
    m_Texto15.Color(clrWhite);
    m_panel.Add(m_Texto15);

    m_Texto16.Create(NULL, "Texto16", 0, panelLarguraTexto02, panelAlturaTexto*1, 1, 1);
    m_Texto16.Text("--->");
    m_Texto16.Color(clrWhite);
    m_panel.Add(m_Texto16);

    m_Texto17.Create(NULL, "Texto17: ", 0, panelLarguraTexto02, panelAlturaTexto*2, 1, 1);
    m_Texto17.Text("--->");
    m_Texto17.Color(clrWhite);
    m_panel.Add(m_Texto17);

    m_Texto18.Create(NULL, "Texto18: ", 0, panelLarguraTexto02, panelAlturaTexto*3, 1, 1);
    m_Texto18.Text("--->");
    m_Texto18.Color(clrWhite);
    m_panel.Add(m_Texto18);

    m_Texto19.Create(NULL, "Texto19: ", 0, panelLarguraTexto02, panelAlturaTexto*4, 1, 1);
    m_Texto19.Text("--->");
    m_Texto19.Color(clrWhite);
    m_panel.Add(m_Texto19);

    m_Texto20.Create(NULL, "Texto20: ", 0, panelLarguraTexto02, panelAlturaTexto*5, 1, 1);
    m_Texto20.Text("--->");
    m_Texto20.Color(clrWhite);
    m_panel.Add(m_Texto20);

    m_Texto21.Create(NULL, "Texto21: ", 0, panelLarguraTexto02, panelAlturaTexto*6, 1, 1);
    m_Texto21.Text("--->");
    m_Texto21.Color(clrWhite);
    m_panel.Add(m_Texto21);

    m_Texto22.Create(NULL, "Texto22: ", 0, panelLarguraTexto02, panelAlturaTexto*7, 1, 1);
    m_Texto22.Text("--->");
    m_Texto22.Color(clrWhite);
    m_panel.Add(m_Texto22);

    m_Texto23.Create(NULL, "Texto23: ", 0, panelLarguraTexto02, panelAlturaTexto*8, 1, 1);
    m_Texto23.Text("--->");
    m_Texto23.Color(clrWhite);
    m_panel.Add(m_Texto23);

    m_Texto24.Create(NULL, "Texto24: ", 0, panelLarguraTexto02, panelAlturaTexto*9, 1, 1);
    m_Texto24.Text("--->");
    m_Texto24.Color(clrWhite);
    m_panel.Add(m_Texto24);

    m_Texto25.Create(NULL, "Texto25: ", 0, panelLarguraTexto02, panelAlturaTexto*10, 1, 1);
    m_Texto25.Text("--->");
    m_Texto25.Color(clrWhite);
    m_panel.Add(m_Texto25);

    m_Texto26.Create(NULL, "Texto26: ", 0, panelLarguraTexto02, panelAlturaTexto*11, 1, 1);
    m_Texto26.Text("--->");
    m_Texto26.Color(clrWhite);
    m_panel.Add(m_Texto26);

    m_Texto27.Create(NULL, "Texto27: ", 0, panelLarguraTexto02, panelAlturaTexto*12, 1, 1);
    m_Texto27.Text("--->");
    m_Texto27.Color(clrWhite);
    m_panel.Add(m_Texto27);

    m_Texto28.Create(NULL, "Texto28: ", 0, panelLarguraTexto02, panelAlturaTexto*13, 1, 1);
    m_Texto28.Text("--->");
    m_Texto28.Color(clrWhite);
    m_panel.Add(m_Texto28);

    m_Texto29.Create(NULL, "Texto29: ", 0, panelLarguraTexto02, panelAlturaTexto*14, 1, 1);
    m_Texto29.Text("--->");
    m_Texto29.Color(clrWhite);
    m_panel.Add(m_Texto29);

    m_Texto30.Create(NULL, "Texto30: ", 0, panelLarguraTexto02, panelAlturaTexto*15, 1, 1);
    m_Texto30.Text("--->");
    m_Texto30.Color(clrWhite);
    m_panel.Add(m_Texto30);

    m_button01.Create(NULL, "zerar", 0, posicaoHorizontalBotaoResetar, posicaoVerticalBotaoResetar, larguraBotaoResetar, alturaBotaoResetar);
    m_button01.Text("ENCERRAR POSICOES");
    m_button01.Color(clrWhite);
    m_button01.ColorBackground(C'28,195,170');
    m_button01.FontSize(10);
    m_panel.Add(m_button01);

//+------------------------------------------------------------------+
//| VERIFICA ERRO NA CRIAÇÃO DO PAINEL                               |
//+------------------------------------------------------------------+

   if(!m_panel.Run()){Print("Robot -> Falha na criação do painel."); return false;}

//+------------------------------------------------------------------+
//| ATUALIZA O PAINEL                                                |
//+------------------------------------------------------------------+

   ChartRedraw();

//+------------------------------------------------------------------+
//| INCONSISTÊNCIAS NOS HORÁRIOS DE NEGOCIAÇÃO                       |
//+------------------------------------------------------------------+

  if(escolheHabilitarRelogio == Ligado)
  {
     MqlDateTime horario_inicio, horario_termino, horario_fechamento;
     TimeToStruct(StringToTime(hora_inicio), horario_inicio);
     TimeToStruct(StringToTime(hora_fim), horario_termino);
     TimeToStruct(StringToTime(hora_zeragem), horario_fechamento);

     if(horario_inicio.hour > horario_termino.hour || (horario_inicio.hour == horario_termino.hour && horario_inicio.min > horario_termino.min))
     {
        printf("Robot -> Parâmetros de Horário inválidos!");
        if(!posiAberta) return INIT_FAILED;
     }

     if(horario_termino.hour > horario_fechamento.hour || (horario_termino.hour == horario_fechamento.hour && horario_termino.min > horario_fechamento.min))
     {
        printf("Robot -> Parâmetros de Horário inválidos!");
        if(!posiAberta) return INIT_FAILED;
     }
  }

//+------------------------------------------------------------------+
//| ATUALIZA O PAINEL GRÁFICO                                        |
//+------------------------------------------------------------------+

   UpdatePanel();
   UpdatePanel02();

//+------------------------------------------------------------------+
//| CONVERSÃO PARA POINTS                                            |
//+------------------------------------------------------------------+

   if(points_ == nao)
   {
      ExtInpStopLoss = InpStopLoss;
      ExtInpTakeProfit = InpTakeProfit;
      ExtBreakEvenStart = Break_Even_Start;
      ExtBreakEvenStep = Break_Even_Step;
      ExtTraillingStart = Trailing_Start;
      ExtTraillingStep = Trailing_Step;
      ExtTamanhoMaximoDaVela = tamanhoMaximoDaVela;
      ExtPontosRompimento = pontosRompimento;
   }

   //---

   if(points_ == sim)
   {
      ExtInpStopLoss = InpStopLoss*_Point;
      ExtInpTakeProfit = InpTakeProfit*_Point;
      ExtBreakEvenStart = Break_Even_Start*_Point;
      ExtBreakEvenStep = Break_Even_Step*_Point;
      ExtTraillingStart = Trailing_Start*_Point;
      ExtTraillingStep = Trailing_Step*_Point;
      ExtTamanhoMaximoDaVela = tamanhoMaximoDaVela*_Point;
      ExtPontosRompimento = pontosRompimento*_Point;
   }

//+------------------------------------------------------------------+
//| FUNÇÃO ONTIMER                                                   |
//+------------------------------------------------------------------+
//| O OnTimer só desenha objetos no gráfico (linhas de SL/TP/BE/TS,  |
//| o desenho do HiLo, o painel) - nenhuma decisão de entrada/saída  |
//| depende dele, isso tudo roda no OnTick. No Strategy Tester, esse |
//| redesenho pesado e repetido (até 1500 objetos de tendência do    |
//| HiLo a cada 3s) trava/congela o terminal. Por isso o timer só é  |
//| ligado fora do tester.                                           |
//+------------------------------------------------------------------+

   if(!MQLInfoInteger(MQL_TESTER))
      EventSetTimer(3);

//+------------------------------------------------------------------+
//| CARREGAMENTO DO ROBÔ NO GRÁFICO                                  |
//+------------------------------------------------------------------+

  Print("ORION EDGE PRO -> Núcleo carregado | Estratégia Virada de HiLo configurada.");

  //---

   return(INIT_SUCCEEDED);

  }

//+------------------------------------------------------------------+
//| FUNÇÃO ON DE INIT                                                |
//+------------------------------------------------------------------+

void OnDeinit(const int reason)
  {

//+------------------------------------------------------------------+
//| MOTIVOS DE REMOÇÃO DO ROBÔ                                       |
//+------------------------------------------------------------------+

   switch(reason)
     {
      case 0:
         Print("Robot -> ATENÇÃO: Motivo da remoção: O Expert Advisor terminou sua operação chamando a função ExpertRemove().");
         break;
      case 1:
         Print("Robot -> ATENÇÃO: Motivo da remoção: O robô foi excluído do gráfico.");
         break;
      case 2:
         Print("Robot -> ATENÇÃO: Motivo da remoção: O robô foi recompilado.");
         break;
      case 3:
         Print("Robot -> ATENÇÃO: Motivo da remoção: O período do símbolo ou gráfico foi alterado.");;
         break;
      case 4:
         Print("Robot -> ATENÇÃO: Motivo da remoção: O gráfico foi encerrado.");
         break;
      case 5:
         Print("Robot -> ATENÇÃO: Motivo da remoção: Os parâmetros de entrada foram alterados pelo usuário.");
         break;
      case 6:
         Print("Robot -> ATENÇÃO: Motivo da remoção: Outra conta foi ativada ou o servidor de negociação foi reconectado devido a alterações nas configurações da conta.");
         break;
      case 7:
         Print("Robot ->  TENÇÃO: Motivo da remoção: Um novo modelo foi aplicado.");
         break;
      case 8:
         Print("Robot -> ATENÇÃO: Motivo da remoção: O manipulador OnInit() retornou um valor diferente de zero.");
         break;
      case 9:
         Print("Robot ->  TENÇÃO: Motivo da remoção: Terminal foi fechado.");
         break;
      default:
         Print("Robot -> ATENÇÃO: Motivo da remoção: Desconhecido.");
     }

//+----------------------------------------------------------------------------+
//| Excluir todos os objetos relacionados ao painel de informações do gráfico  |
//+----------------------------------------------------------------------------+

   m_panel.Destroy(reason);

//+------------------------------------------------------------------+
//| REMOVE TODOS OS INDICADORES DO GRÁFICO                           |
//+------------------------------------------------------------------+

   for(int i=0;i<2;i++)
     RemoveIndicadores();

//+------------------------------------------------------------------+
//| REMOVE OS INDICADORES DA MEMÓRIA                                 |
//+------------------------------------------------------------------+

  IndicatorRelease(handleBB);
  IndicatorRelease(handleMM01);
  IndicatorRelease(handleMM02);
  IndicatorRelease(handleAfastamento);
  IndicatorRelease(handleHiLoHigh);
  IndicatorRelease(handleHiLoLow);
  IndicatorRelease(handleNexusZonas);
  IndicatorRelease(handleVPRange);
  IndicatorRelease(handleSRRejection);
  IndicatorRelease(handleShowTrades);

//+------------------------------------------------------------------+
//| LIMPA OS BUFFERS DA MEMÓRIA                                      |
//+------------------------------------------------------------------+

  ArrayFree(bufferBBSuperior);
  ArrayFree(bufferBBInferior);
  ArrayFree(bufferMM01);
  ArrayFree(bufferMM02);
  ArrayFree(bufferAfastamentoCentral);
  ArrayFree(bufferAfastamentoSuperior);
  ArrayFree(bufferAfastamentoInferior);
  ArrayFree(bufferHiLoHigh);
  ArrayFree(bufferHiLoLow);
  ArrayFree(bufferNexusZonasCompra);
  ArrayFree(bufferNexusZonasVenda);
  ArrayFree(bufferVPRangeCompra);
  ArrayFree(bufferVPRangeVenda);
  ArrayFree(bufferSRRejectionCompra);
  ArrayFree(bufferSRRejectionVenda);

//+------------------------------------------------------------------+
//| DELETA OS BOTÕES DO PAINEL                                       |
//+------------------------------------------------------------------+

   LimpaVisualHiLo();
   ObjectsDeleteAll(0, 0);

//+------------------------------------------------------------------+
//| DESTRÓI A FUNÇÃO ON TIMER                                        |
//+------------------------------------------------------------------+

   EventKillTimer();
  }

//+------------------------------------------------------------------+
//| FUNÇAO ON TIMER                                                  |
//+------------------------------------------------------------------+

  void OnTimer()
  {
    //+------------------------------------------------------------------+
    //| META DA SEMANA                                                   |
    //+------------------------------------------------------------------+

      funcao_verifica_meta_ou_perda_atingida_semana();

    //+------------------------------------------------------------------+
    //| TEMPO GRÁFICO QUE IRÁ ABRIR A JANELA CORRENTE                    |
    //+------------------------------------------------------------------+

      if(ChartPeriod(0) != ENUM_TIMEFRAMES(tempoGrafico))
        ChartSetSymbolPeriod(0, _Symbol, ENUM_TIMEFRAMES(tempoGrafico));

    //+------------------------------------------------------------------+
    //| COPPYBUFFER                                                      |
    //+------------------------------------------------------------------+

      CoppyBuffer();

      if(estrategia == estrategia_virada_hilo)
         AtualizaVisualHiLo();

    //+------------------------------------------------------------------+
    //| MOVIMENTA AS LINHAS                                              |
    //+------------------------------------------------------------------+

      if(posicaoAberta) HLinhaMover("SL"+_Symbol+string(m_magic), stopLossOperacao);
      if(posicaoAberta) HLinhaMover("TP"+_Symbol+string(m_magic), takeProfitOperacao);

    //+------------------------------------------------------------------+
    //| MOVIMENTA AS LINHAS AS RE CONTRA                                 |
    //+------------------------------------------------------------------+

      if(posicaoAberta && ligarAumentosParaTras == Ligado)
      {
        for(int i = 0; i < ObjectsTotal(0, 0, OBJ_HLINE); i++)
        {
           string objeto = ObjectName(0, i, 0, OBJ_HLINE);

           if(StringFind(objeto, "RE", 0) != -1)
           {
             double preco = ObjectGetDouble(0, objeto, OBJPROP_PRICE, 0);
             HLinhaMover(objeto, preco);
           }
        }
      }

    //+------------------------------------------------------------------+
    //| CRIA OS OBJETOS DO STOP MÓVEL e HABILTA O STOP MÓVEL             |
    //+------------------------------------------------------------------+

       if(posicaoAberta)
       {
            //--- BREAKEVEN

            if(Break_Even_Start > 0)
            {
              if(comprado && !vendido && stopLossOperacao < precoMedio)
                 HLinhaMover("BE"+_Symbol+string(m_magic), m_symbol.NormalizePrice(precoMedio + ExtBreakEvenStart));

              if(vendido && !comprado && ((stopLossOperacao > precoMedio && stopLossOperacao > 0) || (stopLossOperacao == 0)))
                 HLinhaMover("BE"+_Symbol+string(m_magic), m_symbol.NormalizePrice(precoMedio - ExtBreakEvenStart));

            } // FINALIZA O BREAKEVEN

            //--- TRAILLING STOP

            if(Trailing_Start > 0 && Trailing_Step > 0)
            {
              if(comprado && !vendido && stopLossOperacao >= precoMedio)
                 HLinhaMover("TS"+_Symbol+string(m_magic), m_symbol.NormalizePrice(stopLossOperacao + ExtTraillingStart));

              if(vendido && !comprado && stopLossOperacao <= precoMedio)
                 HLinhaMover("TS"+_Symbol+string(m_magic), m_symbol.NormalizePrice(stopLossOperacao - ExtTraillingStart));
            } // FINALIZA O TRAILLING STOP
        }

    //+------------------------------------------------------------------+
    //| LINHAS DAS REALIZAÇÕES PARCIAIS                                  |
    //+------------------------------------------------------------------+

      string valuesDistanciaSP[];
      int retDistanciaSP = StringSplit(pontosRealizacao,',',valuesDistanciaSP);

      if(posicaoAberta && retDistanciaSP > 0 && ligarRealizacoesParciais == Ligado)
      {
         for(int i = 0; i < retDistanciaSP; i++)
         {
           double distancia = StringToDouble(valuesDistanciaSP[i]);
           if(points_ == sim) distancia = distancia*_Point;

            if(comprado && !vendido)
            {
               double price_line = m_symbol.NormalizePrice(precoMedio + distancia);
               HLinhaMover("SP"+string(i)+_Symbol+string(m_magic), price_line);
            }else if(vendido && !comprado)
                  {
                     double price_line = m_symbol.NormalizePrice(precoMedio - distancia);
                     HLinhaMover("SP"+string(i)+_Symbol+string(m_magic), price_line);
                  }
         }
      }

    //+------------------------------------------------------------------+
    //| POSIÇÃO ATUAL DA OPERAÇÃO NO PAINEL                              |
    //+------------------------------------------------------------------+

      PosicaoAtual();

    //+------------------------------------------------------------------+
    //| HABILITA O PAINEL GRÁFICO                                        |
    //+------------------------------------------------------------------+

      UpdatePanel02();

    //+------------------------------------------------------------------+
    //| COLOCA AS SETAS DA OPERAÇÃO ATRÁS DO GRÁFICO                     |
    //+------------------------------------------------------------------+

      if(setasAtrasDoGrafico == sim)
        ObjectsArrowToBack();
  }

//+------------------------------------------------------------------+
//| FUNÇÃO ON TICK                                                   |
//+------------------------------------------------------------------+

void OnTick()
  {

/********************************************************************/
//+------------------------------------------------------------------+
//| INICIAL                                                          |
//+------------------------------------------------------------------+
/********************************************************************/

   //+------------------------------------------------------------------+
   //| RESET LAST ERROR                                                 |
   //+------------------------------------------------------------------+

     ResetLastError();

   //+------------------------------------------------------------------+
   //| ATUALIZA OS DADOS DO ATIVO                                       |
   //+------------------------------------------------------------------+

      if(!m_symbol.RefreshRates())
         return;

   //+------------------------------------------------------------------+
   //| TIPO DE ORDEM                                                    |
   //+------------------------------------------------------------------+

      if(escolheHabilitarRelogio == Ligado)
          tipoDeOrdem = ENUM_ORDER_TYPE_TIME(ORDER_TIME_DAY);
      else if(escolheHabilitarRelogio == Desligado)
               tipoDeOrdem = ENUM_ORDER_TYPE_TIME(ORDER_TIME_GTC);

   //+------------------------------------------------------------------+
   //| NOVA BARRA                                                       |
   //+------------------------------------------------------------------+

     novaBarra = isNewBar();

   //+------------------------------------------------------------------+
   //| VARRE AS POSIÇÕES ABERTAS E ORDENS PENDENTES                     |
   //+------------------------------------------------------------------+

      PosicoesEOrdens();

   //+------------------------------------------------------------------+
   //| QUANTIDADE DE TRADES NO DIA                                      |
   //+------------------------------------------------------------------+

      if(tradesPorDia > 0)
         quantidadeDeTrades = funcao_verifica_quantidade_de_trades_no_dia();

   //+------------------------------------------------------------------+
   //| DIA E HORA                                                       |
   //+------------------------------------------------------------------+

      hoje = TimeToString(TimeCurrent(),TIME_DATE);
      hora_atual = TimeCurrent();

   //+------------------------------------------------------------------+
   //| VARIÁVEIS GLOBAIS                                                |
   //+------------------------------------------------------------------+

     if(!GlobalVariableCheck("hoje_"+_Symbol+string(m_magic))) GlobalVariableSet("hoje_"+_Symbol+string(m_magic), 0);
     hoje_ = GlobalVariableGet("hoje_"+_Symbol+string(m_magic));

     //---

     if(meta_diaria_lucro > 0 || meta_diaria_prejuizo > 0)
     {
       if(!GlobalVariableCheck("meta"+_Symbol+string(m_magic))) GlobalVariableSet("meta"+_Symbol+string(m_magic), 0);
       meta_batida = GlobalVariableGet("meta"+_Symbol+string(m_magic));
     }

   //+------------------------------------------------------------------+
   //| FUNÇÃO PARA O CÁLCULO DO BACKTEST                                |
   //+------------------------------------------------------------------+

      MqlDateTime str1;
      diaAtual = TimeCurrent();
      TimeToStruct(diaAtual,str1);
      double dia = str1.day;

      if(hoje_ != dia) GlobalVariableSet("hoje_"+_Symbol+string(m_magic), 0);

      //--- Dia

      if(hoje_ != dia)
      {
         GlobalVariableSet("meta"+_Symbol+string(m_magic), 0);
         meta_batida = GlobalVariableGet("meta"+_Symbol+string(m_magic));
         GlobalVariableSet("hoje_"+_Symbol+string(m_magic), dia);
         hoje_ = GlobalVariableGet("hoje_"+_Symbol+string(m_magic));
         pos_price = 0.0;
         pos_price_semana = 0.0;
         pos_price_mes = 0.0;
         pos_trades = 0;
         pos_trades_semana = 0;
         pos_trades_mes = 0;
         porcentagemAcertos = 0.0;
         trades_positivos = 0;
         porcentagemAcertos_mes = 0.0;
         trades_positivos_mes = 0;
         porcentagemAcertos_semana = 0.0;
         trades_positivos_semana = 0;
         funcao_verifica_meta_ou_perda_atingida_semana();
         funcao_verifica_meta_ou_perda_atingida_mes();
      }

   //+------------------------------------------------------------------+
   //| METAS FINANCEIRAS                                                |
   //+------------------------------------------------------------------+

     if(meta_batida == 0) metaDiaria = "Não Batida";
     if(meta_batida == 1) metaDiaria = "Batida";

   //+------------------------------------------------------------------+
   //| FUNÇÃO META DO DIA                                               |
   //+------------------------------------------------------------------+

     funcao_verifica_meta_ou_perda_atingida();

/*******************************************************************/
//+-----------------------------------------------------------------+
//| HORÁRIO DE TÉRMINO DAS OPERAÇÕES                                |
//+-----------------------------------------------------------------+
/*******************************************************************/

   if(!posicaoAberta && escolheHabilitarRelogio == Ligado && hora_atual >= (StringToTime(hoje+" "+hora_fim)))
     if(ordPendente){ DeletaOrdens(); PosicoesEOrdens(); }

   //---

   if(escolheHabilitarRelogio == Ligado && hora_atual >= (StringToTime(hoje+" "+hora_zeragem)))
   {
      if(ordPendente){ DeletaOrdens(); PosicoesEOrdens(); }
      if(posicaoAberta){ zerar(); PosicoesEOrdens(); }
   }

/********************************************************************/
//+------------------------------------------------------------------+
//| HABILITA O PAINEL GRÁFICO                                        |
//+------------------------------------------------------------------+
/********************************************************************/

  UpdatePanel();

/********************************************************************/
//+------------------------------------------------------------------+
//| VARRE OS OBJETOS DO GRÁFICO                                      |
//+------------------------------------------------------------------+
/********************************************************************/

  if(!posicaoAberta && !ordPendente)
  {
     if(ObjectsTotal(0, 0, OBJ_HLINE) > 0)
     {
        for(int i = 0; i < ObjectsTotal(0, 0, OBJ_HLINE); i++)
        {
           string objeto = ObjectName(0, i, 0, OBJ_HLINE);
           HLinhaDeletar(objeto);
        }
     }
  }

/******************************************************************************/
//+----------------------------------------------------------------------------+
//| VERIFICA SE A VARIÁVEL DAS METAS FOI ALTERADA PARA TRUE                    |
//+----------------------------------------------------------------------------+
/******************************************************************************/

   if(meta_batida == 1 && (posicaoAberta || ordPendente))
   {
      if(posicaoAberta){ zerar(); PosicoesEOrdens(); }
      if(ordPendente){ DeletaOrdens(); PosicoesEOrdens(); }
   }

   //---

   if(meta_batida == 1) return;

/********************************************************************/
//+------------------------------------------------------------------+
//| NÃO EXISTEM POSIÇÕES ABERTAS                                     |
//+------------------------------------------------------------------+
/********************************************************************/

      //+------------------------------------------------------------------+
      //| VALIDADE DO ROBÔ                                                 |
      //+------------------------------------------------------------------+

        if(!posicaoAberta && !ordPendente && TerminalInfoInteger(TERMINAL_CONNECTED) && string(TimeCurrent()) > dataHora)
        {
          Print("Licença Expirada. ");
          Comment("Licença Expirada. ");
          m_panel.Destroy(0);
          for(int i=0;i<3;i++) RemoveIndicadores();
          ExpertRemove();
        }

      //+------------------------------------------------------------------+
      //| CANDLE OPERADO                                                   |
      //+------------------------------------------------------------------+

        if(novaBarra && !posicaoAberta) candle_operado = false;

      //+------------------------------------------------------------------+
      //| DELETA ORDEM PENDENTE                                            |
      //+------------------------------------------------------------------+

        if(!posicaoAberta && ordPendente) DeletaOrdens();

      //+------------------------------------------------------------------+
      //| RESETA VARIÁVEIS                                                 |
      //+------------------------------------------------------------------+

         if(!posicaoAberta)
         {
           criarLinhasSP = false;
           precoDeEntradaRE = 0.0;
           if(ligarAumentosParaTras == Ligado) GlobalVariableSet("RE"+_Symbol+string(m_magic), 0);
         }

      //+------------------------------------------------------------------+
      //| DELETA AS VARIÁVEIS GLOBAIS DAS SAÍDAS PARCIAIS                  |
      //+------------------------------------------------------------------+

        if(!posicaoAberta && !ordPendente && GlobalVariableCheck("SP0"+_Symbol+string(m_magic)))
        {
           m_symbol.RefreshRates();

           string valuesPontosSP[];
           int retPontosSP = StringSplit(pontosRealizacao,',',valuesPontosSP);

           if(retPontosSP > 0)
           {
             for(int i = 0; i < retPontosSP; i++)
               GlobalVariableDel("SP"+string(i)+_Symbol+string(m_magic));
           }
        }

/********************************************************************/
//+------------------------------------------------------------------+
//| EXISTEM POSIÇÕES ABERTAS                                         |
//+------------------------------------------------------------------+
/********************************************************************/

      //+------------------------------------------------------------------+
      //| PREÇO MÉDIO                                                      |
      //+------------------------------------------------------------------+

          if(posicaoAberta)
            precoMedio = GetCurrentMeanPrice(_Symbol, m_magic);

      //+------------------------------------------------------------------+
      //| DESENHA AS LINHAS DE TP, SL E PREÇO DE ENTRADA                   |
      //+------------------------------------------------------------------+

          if(posicaoAberta && ObjectFind(0, "SL"+_Symbol+string(m_magic)) < 0) HLinhaCriar("SL"+_Symbol+string(m_magic), stopLossOperacao, "Stop Loss", clrRed, clrWhite, 130);
          if(posicaoAberta && ObjectFind(0, "TP"+_Symbol+string(m_magic)) < 0) HLinhaCriar("TP"+_Symbol+string(m_magic), takeProfitOperacao, "TakeProfit", clrMidnightBlue, clrWhite, 130);
          if(posicaoAberta && ObjectFind(0, "Entrada"+_Symbol+string(m_magic)) < 0) HLinhaCriar("Entrada"+_Symbol+string(m_magic), precoMedio, "Entrada", clrBlack, clrWhite, 130);
          if(posicaoAberta) HLinhaMoverEntrada("Entrada"+_Symbol+string(m_magic), precoMedio);

      //+------------------------------------------------------------------+
      //| LUCRO E PREJUÍZO DA OPERAÇÃO                                     |
      //+------------------------------------------------------------------+

        if(posicaoAberta)
        {
           if(((lucroPosicoes >= meta_operacao_lucro && meta_operacao_lucro > 0) || (lucroPosicoes <= meta_operacao_prejuizo*(-1) && meta_operacao_prejuizo > 0)))
           {
             if(ordPendente) DeletaOrdens();
             if(posicaoAberta) zerar();
             Print("Robot -> Saída pelo Lucro/Prejuízo Máximo da Operação. Preço: "+DoubleToString(lucroPosicoes, 2));
           }
        }

      //+------------------------------------------------------------------+
      //| PEGA A DATA E A HORA DA ÚLTIMA ENTRADA OCORRIDA                  |
      //+------------------------------------------------------------------+

        if(!posicaoAberta) data_e_hora_ultima_entrada = 0;

        if(posicaoAberta && data_e_hora_ultima_entrada == 0)
          data_e_hora_ultima_entrada = funcao_data_ultima_entrada_operacao();

      //+------------------------------------------------------------------+
      //| CRIA OS OBJETOS DO STOP MÓVEL e HABILTA O STOP MÓVEL             |
      //+------------------------------------------------------------------+

         if(posicaoAberta)
           BETS();

      //+------------------------------------------------------------------+
      //| CHAMA A FUNÇÃO DE REALIZAÇÕES PARCIAIS                           |
      //+------------------------------------------------------------------+

        if(posicaoAberta && ligarRealizacoesParciais == Ligado)
          SaidasParciais();

      //+------------------------------------------------------------------+
      //| CHAMA A FUNÇÃO DOS AUMENTOS DE POSIÇÃO CONTRA                    |
      //+------------------------------------------------------------------+

        if(posicaoAberta && ligarAumentosParaTras == Ligado)
          ReentradasContra();

/********************************************************************/
//+------------------------------------------------------------------+
//| COM E SEM POSIÇÕES ABERTAS                                       |
//+------------------------------------------------------------------+
/********************************************************************/

   //+------------------------------------------------------------------+
   //| META FINANCEIRA DIÁRIA                                           |
   //+------------------------------------------------------------------+

      if((pos_price + lucroPosicoes) >= meta_diaria_lucro && meta_diaria_lucro > 0)
      {
         if(ordPendente){ DeletaOrdens(); PosicoesEOrdens(); }
         if(posicaoAberta){ zerar(); PosicoesEOrdens(); }
         GlobalVariableSet("meta"+_Symbol+string(m_magic), 1);
         meta_batida = GlobalVariableGet("meta"+_Symbol+string(m_magic));
      }

      //---

      if((pos_price + lucroPosicoes) <= meta_diaria_prejuizo*(-1) && meta_diaria_prejuizo > 0)
      {
         if(ordPendente){ DeletaOrdens(); PosicoesEOrdens(); }
         if(posicaoAberta){ zerar(); PosicoesEOrdens(); }
         GlobalVariableSet("meta"+_Symbol+string(m_magic), 1);
         meta_batida = GlobalVariableGet("meta"+_Symbol+string(m_magic));
      }

/********************************************************************/
//+------------------------------------------------------------------+
//| ENTRADAS DE COMPRA E DE VENDA                                    |
//+------------------------------------------------------------------+
/********************************************************************/

      //+------------------------------------------------------------------+
      //| ENTRADAS DE COMPRA E DE VENDA - ESTRATÉGIA BANDAS DE BOLLINGER   |
      //+------------------------------------------------------------------+

        if(estrategia == estrategia_bb)
        if((quantidadeDeTrades < tradesPorDia && tradesPorDia > 0) || (tradesPorDia == 0))
        if(((escolheHabilitarRelogio == Ligado && hora_atual>=(StringToTime(hoje+" "+hora_inicio)) && hora_atual<=(StringToTime(hoje+" "+hora_fim))) || (escolheHabilitarRelogio == Desligado)) && meta_batida == 0 && !posicaoAberta && !ordPendente && !candle_operado)
          funcaoComprasEVendasBB();

      //+------------------------------------------------------------------+
      //| ENTRADAS DE COMPRA E DE VENDA - ESTRATÉGIA CRUZAMENTO DE MÉDIAS  |
      //+------------------------------------------------------------------+

        if(estrategia == estrategia_cruzamento_de_medias)
        if((quantidadeDeTrades < tradesPorDia && tradesPorDia > 0) || (tradesPorDia == 0))
        if((confirmacaoCM == sem_confirmacao) || (confirmacaoCM == com_confirmacao && novaBarra))
        if(((escolheHabilitarRelogio == Ligado && hora_atual>=(StringToTime(hoje+" "+hora_inicio)) && hora_atual<=(StringToTime(hoje+" "+hora_fim))) || (escolheHabilitarRelogio == Desligado)) && meta_batida == 0 && !posicaoAberta && !ordPendente && !candle_operado)
          funcaoComprasEVendasCM();

      //+------------------------------------------------------------------+
      //| ENTRADAS DE COMPRA E DE VENDA - ESTRATÉGIA AFASTAMENTO DE MÉDIA  |
      //+------------------------------------------------------------------+

        if(estrategia == estrategia_afastamento_de_media)
        if((quantidadeDeTrades < tradesPorDia && tradesPorDia > 0) || (tradesPorDia == 0))
        if(((escolheHabilitarRelogio == Ligado && hora_atual>=(StringToTime(hoje+" "+hora_inicio)) && hora_atual<=(StringToTime(hoje+" "+hora_fim))) || (escolheHabilitarRelogio == Desligado)) && meta_batida == 0 && !posicaoAberta && !ordPendente && !candle_operado)
          funcaoComprasEVendasAfastamento();

      //+------------------------------------------------------------------+
      //| ENTRADAS DE COMPRA E DE VENDA - ESTRATÉGIA PRICE ACTION          |
      //+------------------------------------------------------------------+

        if(estrategia == estrategia_price_action)
        if((quantidadeDeTrades < tradesPorDia && tradesPorDia > 0) || (tradesPorDia == 0))
        if(((escolheHabilitarRelogio == Ligado && hora_atual>=(StringToTime(hoje+" "+hora_inicio)) && hora_atual<=(StringToTime(hoje+" "+hora_fim))) || (escolheHabilitarRelogio == Desligado)) && meta_batida == 0 && !posicaoAberta && !ordPendente && !candle_operado)
          funcaoComprasEVendasPA();

      //+------------------------------------------------------------------+
      //| ENCERRAMENTO DA POSIÇÃO NA VIRADA DO HILO                       |
      //+------------------------------------------------------------------+

        if(estrategia == estrategia_virada_hilo &&
           encerrarOperacaoHilo == sim &&
           posicaoAberta &&
           ((confirmacaoHiLo == sem_confirmacao) || (confirmacaoHiLo == com_confirmacao && novaBarra)))
           funcaoEncerrarOperacaoViradaHiLo();

      //+------------------------------------------------------------------+
      //| ENTRADAS DE COMPRA E DE VENDA - VIRADA DE HILO                  |
      //+------------------------------------------------------------------+

        if(estrategia == estrategia_virada_hilo)
        if((quantidadeDeTrades < tradesPorDia && tradesPorDia > 0) || (tradesPorDia == 0))
        if((confirmacaoHiLo == sem_confirmacao) || (confirmacaoHiLo == com_confirmacao && novaBarra))
        if(((escolheHabilitarRelogio == Ligado && hora_atual>=(StringToTime(hoje+" "+hora_inicio)) && hora_atual<=(StringToTime(hoje+" "+hora_fim))) || (escolheHabilitarRelogio == Desligado)) && meta_batida == 0 && !posicaoAberta && !ordPendente && !candle_operado)
          funcaoComprasEVendasHiLo();

      //+------------------------------------------------------------------+
      //| ENTRADAS DE COMPRA E DE VENDA - NEXUS ZONAS                      |
      //+------------------------------------------------------------------+

        if(estrategia == estrategia_nexus_zonas)
        if((quantidadeDeTrades < tradesPorDia && tradesPorDia > 0) || (tradesPorDia == 0))
        if((confirmacaoNexusZonas == sem_confirmacao) || (confirmacaoNexusZonas == com_confirmacao && novaBarra))
        if(((escolheHabilitarRelogio == Ligado && hora_atual>=(StringToTime(hoje+" "+hora_inicio)) && hora_atual<=(StringToTime(hoje+" "+hora_fim))) || (escolheHabilitarRelogio == Desligado)) && meta_batida == 0 && !posicaoAberta && !ordPendente && !candle_operado)
          funcaoComprasEVendasNexusZonas();

      //+------------------------------------------------------------------+
      //| ENTRADAS DE COMPRA E DE VENDA - VPRANGE                          |
      //+------------------------------------------------------------------+

        if(estrategia == estrategia_vprange)
        if((quantidadeDeTrades < tradesPorDia && tradesPorDia > 0) || (tradesPorDia == 0))
        if((confirmacaoVPRange == sem_confirmacao) || (confirmacaoVPRange == com_confirmacao && novaBarra))
        if(((escolheHabilitarRelogio == Ligado && hora_atual>=(StringToTime(hoje+" "+hora_inicio)) && hora_atual<=(StringToTime(hoje+" "+hora_fim))) || (escolheHabilitarRelogio == Desligado)) && meta_batida == 0 && !posicaoAberta && !ordPendente && !candle_operado)
          funcaoComprasEVendasVPRange();

      //+------------------------------------------------------------------+
      //| ENTRADAS DE COMPRA E DE VENDA - SUPPORT RESISTANCE REJECTION PRO |
      //+------------------------------------------------------------------+

        if(estrategia == estrategia_sr_rejection)
        if((quantidadeDeTrades < tradesPorDia && tradesPorDia > 0) || (tradesPorDia == 0))
        if((confirmacaoSRRejection == sem_confirmacao) || (confirmacaoSRRejection == com_confirmacao && novaBarra))
        if(((escolheHabilitarRelogio == Ligado && hora_atual>=(StringToTime(hoje+" "+hora_inicio)) && hora_atual<=(StringToTime(hoje+" "+hora_fim))) || (escolheHabilitarRelogio == Desligado)) && meta_batida == 0 && !posicaoAberta && !ordPendente && !candle_operado)
          funcaoComprasEVendasSRRejection();

/********************************************************************/
//+------------------------------------------------------------------+
//| GUARDA AS VARIÁVEIS GLOBAIS DO TERMINAL NO DISCO                 |
//+------------------------------------------------------------------+
/********************************************************************/

  GlobalVariablesFlush();

} // FINAL DA FUNÇÃO ONTICK()

//+------------------------------------------------------------------+
//| CRIA OS OBJETOS DO STOP MÓVEL e HABILTA O STOP MÓVEL             |
//+------------------------------------------------------------------+

  void BETS()
  {
     //--- BREAKEVEN

      if(Break_Even_Start > 0)
      {
         if((comprado && !vendido) || (vendido && !comprado))
            funcaoHabilitaBreakEvenTraillingStop();

         if(comprado && !vendido && stopLossOperacao < precoMedio)
           if(ObjectFind(0, "BE"+_Symbol+string(m_magic)) < 0) HLinhaCriar("BE"+_Symbol+string(m_magic), m_symbol.NormalizePrice(precoMedio + ExtBreakEvenStart), "Breakeven", clrLimeGreen, clrWhite, 130);

         if(comprado && !vendido && stopLossOperacao >= precoMedio) HLinhaDeletar("BE"+_Symbol+string(m_magic));

         if(vendido && !comprado && ((stopLossOperacao > precoMedio && stopLossOperacao > 0) || (stopLossOperacao == 0)))
           if(ObjectFind(0, "BE"+_Symbol+string(m_magic)) < 0) HLinhaCriar("BE"+_Symbol+string(m_magic), m_symbol.NormalizePrice(precoMedio - ExtBreakEvenStart), "Breakeven", clrLimeGreen, clrWhite, 130);

         if(vendido && !comprado && stopLossOperacao <= precoMedio) HLinhaDeletar("BE"+_Symbol+string(m_magic));
      } // FINALIZA O BREAKEVEN

     //--- TRAILLING STOP

      if(Trailing_Start > 0 && Trailing_Step > 0)
      {
         if(comprado && !vendido && stopLossOperacao >= precoMedio)
           if(ObjectFind(0, "TS"+_Symbol+string(m_magic)) < 0) HLinhaCriar("TS"+_Symbol+string(m_magic), m_symbol.NormalizePrice(stopLossOperacao + ExtTraillingStart), "Trailling Stop", clrRed, clrWhite, 130);

         if(vendido && !comprado && stopLossOperacao <= precoMedio)
           if(ObjectFind(0, "TS"+_Symbol+string(m_magic)) < 0) HLinhaCriar("TS"+_Symbol+string(m_magic), m_symbol.NormalizePrice(stopLossOperacao - ExtTraillingStart), "Trailling Stop", clrRed, clrWhite, 130);

         if((comprado && !vendido && stopLossOperacao >= precoMedio) || (vendido && !comprado && stopLossOperacao <= precoMedio))
            funcaoHabilitaBreakEvenTraillingStop();
      } // FINALIZA O TRAILLING STOP
  }

//+--------------------------------------------------------------------------------------+
//| HABILITA BE E TS                                                                     |
//+--------------------------------------------------------------------------------------+

  void funcaoHabilitaBreakEvenTraillingStop()
  {
    if(posicaoAberta && Break_Even_Start > 0)
      BreakEven();

    if(posicaoAberta && Trailing_Start > 0 && Trailing_Step > 0)
      TrailingStop();
  }

//+------------------------------------------------------------------+
//| TRAILLING STOP                                                   |
//+------------------------------------------------------------------+

  void TrailingStop()
  {
     for(int i=PositionsTotal()-1; i>=0; i--)
     {
        if(!PositionSelectByTicket(PositionGetTicket(i))) continue;

        string symbol = PositionGetSymbol(i);
        ulong magic = PositionGetInteger(POSITION_MAGIC);

        if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && symbol == _Symbol)
        {
           ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
           double StopLossCorrente = PositionGetDouble(POSITION_SL);
           double TakeProfitCorrente = PositionGetDouble(POSITION_TP);
           double precoCorrente = PositionGetDouble(POSITION_PRICE_CURRENT);

           if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
           {
             double novoSL = m_symbol.NormalizePrice(StopLossCorrente+ExtTraillingStep);

             if(precoCorrente >= m_symbol.NormalizePrice(StopLossCorrente+ExtTraillingStart) && novoSL > StopLossCorrente && precoCorrente > novoSL && StopLossCorrente >= precoMedio)
             {
               if(m_trade.PositionModify(PositionTicket,novoSL,TakeProfitCorrente))
                  Print("Robot -> TrailingStop executado com sucesso. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
               else Print("Robot -> Não foi possível executar o Trailling Stop. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
             }
           }else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                 {
                    double novoSL = m_symbol.NormalizePrice(StopLossCorrente-ExtTraillingStep);

                    if(precoCorrente <= m_symbol.NormalizePrice(StopLossCorrente-ExtTraillingStart) && novoSL < StopLossCorrente && precoCorrente < novoSL && StopLossCorrente <= precoMedio)
                    {
                       if(m_trade.PositionModify(PositionTicket,novoSL,TakeProfitCorrente))
                          Print("Robot -> TrailingStop executado com sucesso. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                       else Print("Robot -> Não foi possível executar o Trailling Stop. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                    }
                 }
        }
     }
  }

//+------------------------------------------------------------------+
//| BREAKEVEN                                                        |
//+------------------------------------------------------------------+

  void BreakEven()
  {
     for(int i=PositionsTotal()-1; i>=0; i--)
     {
        if(!PositionSelectByTicket(PositionGetTicket(i))) continue;

        string symbol = PositionGetSymbol(i);
        ulong magic = PositionGetInteger(POSITION_MAGIC);

        if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && symbol == _Symbol)
        {
         ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
         double TakeProfitCorrente=PositionGetDouble(POSITION_TP);
         double StopLossCorrente=PositionGetDouble(POSITION_SL);
         double precoCorrente = PositionGetDouble(POSITION_PRICE_CURRENT);

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            double be = m_symbol.NormalizePrice(precoMedio+ExtBreakEvenStep);

            if(precoCorrente >= m_symbol.NormalizePrice(precoMedio+ExtBreakEvenStart) && precoCorrente > be && StopLossCorrente != be && StopLossCorrente < precoMedio)
            {
               if(m_trade.PositionModify(PositionTicket, be, TakeProfitCorrente))
               {
                  Print("Robot -> BreakEven executado com sucesso. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                  HLinhaDeletar("breakeven"+_Symbol+string(m_magic));
               }else Print("Robot -> Não foi possível executar o Breakeven. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
             }
         }
         else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
              {
                 double be = m_symbol.NormalizePrice(precoMedio-ExtBreakEvenStep);

                 if(precoCorrente <= m_symbol.NormalizePrice(precoMedio-ExtBreakEvenStart) && precoCorrente < be && StopLossCorrente != be && ((StopLossCorrente > precoMedio && StopLossCorrente > 0) || (StopLossCorrente == 0)))
                 {
                   if(m_trade.PositionModify(PositionTicket, be, TakeProfitCorrente))
                   {
                     Print("Robot -> BreakEven executado com sucesso. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                     HLinhaDeletar("breakeven"+_Symbol+string(m_magic));
                   }else Print("Robot -> Não foi possível executar o Breakeven. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                 }
              }
        }
     }
  }

//+------------------------------------------------------------------+
//| COMENTÁRIO DA POSIÇÃO                                            |
//+------------------------------------------------------------------+

  bool ComentarioPosicao()
  {
     for(int i = PositionsTotal()-1; i>=0; i--)
     {
        ulong posTicket = PositionGetTicket(i);

        if(PositionSelectByTicket(posTicket))
        {
           string symbol = PositionGetString(POSITION_SYMBOL);
           ulong magic = PositionGetInteger(POSITION_MAGIC);
           string coment = PositionGetString(POSITION_COMMENT);

           if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && symbol == _Symbol)
           {
             if(StringFind(coment, "C_Robot", 0) != -1 || StringFind(coment, "V_Robot", 0) != -1)
             {
               return true;
               break;
             }
           }
        }
     }
     return false;
  }

//+------------------------------------------------------------------+
//| COMENTÁRIO DA ORDEM DA ENTRADA                                   |
//+------------------------------------------------------------------+

  bool ComentarioOrdemEntrada()
  {
     for(int i = OrdersTotal()-1; i>=0; i--)
     {
        ulong orderTicket = OrderGetTicket(i);

        if(OrderSelect(orderTicket))
        {
           string symbol = OrderGetString(ORDER_SYMBOL);
           ulong magic = OrderGetInteger(ORDER_MAGIC);
           string coment = OrderGetString(ORDER_COMMENT);

           if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && symbol == _Symbol)
           {
             if(StringFind(coment, "C_Robot", 0) != -1 || StringFind(coment, "V_Robot", 0) != -1)
             {
               return true;
               break;
             }
           }
        }
     }
     return false;
  }

//+------------------------------------------------------------------+
//| NOVA BARRA                                                       |
//+------------------------------------------------------------------+

  bool isNewBar()
  {
      static datetime last_time=0;
      datetime lastbar_time=(datetime)SeriesInfoInteger(Symbol(),ENUM_TIMEFRAMES(tempoGrafico),SERIES_LASTBAR_DATE);

      if(last_time==0)
      {
         last_time=lastbar_time;
         return(false);
      }

      if(last_time!=lastbar_time)
      {
         last_time=lastbar_time;
         return(true);
      }

      return(false);
  }

//+------------------------------------------------------------------+
//| POSIÇÕES E ORDENS                                                |
//+------------------------------------------------------------------+

  void PosicoesEOrdens()
  {
      //+------------------------------------------------------------------+
      //| LOOP NAS POSIÇÕES ABERTAS E ORDENS PENDENTES COM BREAK           |
      //+------------------------------------------------------------------+

        posicaoAberta = false;
        precoDeEntradaOperacao = 0.0;
        takeProfitOperacao = 0.0;
        stopLossOperacao = 0.0;
        volumeOperacao = 0.0;
        ticketOperacao = 0;
        comentario = "";

        for(int i = PositionsTotal()-1; i>=0; i--)
        {
           ulong posTicket = PositionGetTicket(i);

           if(PositionSelectByTicket(posTicket))
           {
              string symbol = PositionGetString(POSITION_SYMBOL);
              ulong magic = PositionGetInteger(POSITION_MAGIC);

              if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && symbol == _Symbol)
              {
                 posicaoAberta = true;
                 precoDeEntradaOperacao = PositionGetDouble(POSITION_PRICE_OPEN);
                 takeProfitOperacao = PositionGetDouble(POSITION_TP);
                 stopLossOperacao = PositionGetDouble(POSITION_SL);
                 volumeOperacao = PositionGetDouble(POSITION_VOLUME);
                 comentario = PositionGetString(POSITION_COMMENT);
                 ticketOperacao = posTicket;
                 break;
              }
           }
        }

        ordPendente = false;

        for(int i = OrdersTotal()-1; i>=0; i--)
        {
           ulong ticket = OrderGetTicket(i);

           if(OrderSelect(ticket))
           {
              string symbol = OrderGetString(ORDER_SYMBOL);
              ulong magic = OrderGetInteger(ORDER_MAGIC);

              if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && symbol == _Symbol)
                 ordPendente = true;
           }
        }

      //+------------------------------------------------------------------+
      //| LOOP NAS POSIÇÕES ABERTAS SEM BREAK                              |
      //+------------------------------------------------------------------+

        lucroPosicoes = 0.0;
        volumeDaPosicaoAberta = 0.0;
        posicoesAbertas = 0;
        comprado = false;
        vendido = false;

        if(posicaoAberta)
        {
            for(int i=PositionsTotal()-1; i>=0; i--)
            {
              ulong posTicket = PositionGetTicket(i);

              if(PositionSelectByTicket(posTicket))
              {
                 string simbolo_ = PositionGetString(POSITION_SYMBOL);
                 ulong magic = PositionGetInteger(POSITION_MAGIC);
                 ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

                 if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && simbolo_ == _Symbol)
                 {
                    lucroPosicoes += PositionGetDouble(POSITION_PROFIT);
                    volumeDaPosicaoAberta += PositionGetDouble(POSITION_VOLUME);
                    if(posType == POSITION_TYPE_BUY) comprado = true;
                    if(posType == POSITION_TYPE_SELL) vendido = true;
                    posicoesAbertas++;
                 }
              }
            }
        }
  }

//+------------------------------------------------------------------+
//| FUNÇÃO DE COMPRAS E VENDAS - ESTRATÉGIA BANDAS DE BOLLINGER      |
//+------------------------------------------------------------------+

   void funcaoComprasEVendasBB()
   {
      //+------------------------------------------------------------------+
      //| COPPYBUFFER                                                      |
      //+------------------------------------------------------------------+

        CoppyBuffer();

      //+------------------------------------------------------------------+
      //| DELETA LINHAS                                                    |
      //+------------------------------------------------------------------+

        HLinhaDeletar("SL"+_Symbol+string(m_magic));
        HLinhaDeletar("TP"+_Symbol+string(m_magic));
        HLinhaDeletar("Entrada"+_Symbol+string(m_magic));
        HLinhaDeletar("BE"+_Symbol+string(m_magic));
        HLinhaDeletar("TS"+_Symbol+string(m_magic));

      //+------------------------------------------------------------------+
      //| ROTEAMENTO DE COMPRA                                             |
      //+------------------------------------------------------------------+

        if((tendenciaBB == a_favor_da_tendencia && candle[0].open < bufferBBSuperior[0] && SymbolInfoDouble(_Symbol, SYMBOL_ASK) >= bufferBBSuperior[0]) || (tendenciaBB == contra_a_tendencia && candle[0].open > bufferBBInferior[0] && SymbolInfoDouble(_Symbol, SYMBOL_ASK) <= bufferBBInferior[0]))
        {
          double sl = 0.0;
          double tp = 0.0;

          if(InpStopLoss > 0) sl = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - ExtInpStopLoss);
          if(InpTakeProfit > 0) tp = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + ExtInpTakeProfit);

          OpenBuy(sl, tp);
        }

      //+------------------------------------------------------------------+
      //| ROTEAMENTO DE VENDA                                              |
      //+------------------------------------------------------------------+

        if((tendenciaBB == a_favor_da_tendencia && candle[0].open > bufferBBInferior[0] && SymbolInfoDouble(_Symbol, SYMBOL_BID) <= bufferBBInferior[0]) || (tendenciaBB == contra_a_tendencia && candle[0].open < bufferBBSuperior[0] && SymbolInfoDouble(_Symbol, SYMBOL_BID) >= bufferBBSuperior[0]))
        {
          double sl = 0.0;
          double tp = 0.0;

          if(InpStopLoss > 0)sl = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) + ExtInpStopLoss);
          if(InpTakeProfit > 0)tp = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) - ExtInpTakeProfit);

          OpenSell(sl, tp);
        }
   }

//+------------------------------------------------------------------+
//| FUNÇÃO DE COMPRAS E VENDAS - ESTRATÉGIA CRUZAMENTO DE MÉDIAS     |
//+------------------------------------------------------------------+

   void funcaoComprasEVendasCM()
   {
      //+------------------------------------------------------------------+
      //| COPPYBUFFER                                                      |
      //+------------------------------------------------------------------+

        CoppyBuffer();

      //+------------------------------------------------------------------+
      //| DELETA LINHAS                                                    |
      //+------------------------------------------------------------------+

        HLinhaDeletar("SL"+_Symbol+string(m_magic));
        HLinhaDeletar("TP"+_Symbol+string(m_magic));
        HLinhaDeletar("Entrada"+_Symbol+string(m_magic));
        HLinhaDeletar("BE"+_Symbol+string(m_magic));
        HLinhaDeletar("TS"+_Symbol+string(m_magic));

      //+------------------------------------------------------------------+
      //| ROTEAMENTO DE COMPRA                                             |
      //+------------------------------------------------------------------+

        if((confirmacaoCM == sem_confirmacao && bufferMM01[1] < bufferMM02[1] && bufferMM01[0] > bufferMM02[0]) || (confirmacaoCM == com_confirmacao && bufferMM01[2] < bufferMM02[2] && bufferMM01[1] > bufferMM02[1]))
        {
          double sl = 0.0;
          double tp = 0.0;

          if(InpStopLoss > 0) sl = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - ExtInpStopLoss);
          if(InpTakeProfit > 0) tp = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + ExtInpTakeProfit);

          OpenBuy(sl, tp);
        }

      //+------------------------------------------------------------------+
      //| ROTEAMENTO DE VENDA                                              |
      //+------------------------------------------------------------------+

        if((confirmacaoCM == sem_confirmacao && bufferMM01[1] > bufferMM02[1] && bufferMM01[0] < bufferMM02[0]) || (confirmacaoCM == com_confirmacao && bufferMM01[2] > bufferMM02[2] && bufferMM01[1] < bufferMM02[1]))
        {
          double sl = 0.0;
          double tp = 0.0;

          if(InpStopLoss > 0) sl = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) + ExtInpStopLoss);
          if(InpTakeProfit > 0) tp = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) - ExtInpTakeProfit);

          OpenSell(sl, tp);
        }
   }

//+------------------------------------------------------------------+
//| FUNÇÃO DE COMPRAS E VENDAS - ESTRATÉGIA AFASTAMENTO DE MÉDIA     |
//+------------------------------------------------------------------+

   void funcaoComprasEVendasAfastamento()
   {
      //+------------------------------------------------------------------+
      //| COPPYBUFFER                                                      |
      //+------------------------------------------------------------------+

        CoppyBuffer();

      //+------------------------------------------------------------------+
      //| DELETA LINHAS                                                    |
      //+------------------------------------------------------------------+

        HLinhaDeletar("SL"+_Symbol+string(m_magic));
        HLinhaDeletar("TP"+_Symbol+string(m_magic));
        HLinhaDeletar("Entrada"+_Symbol+string(m_magic));
        HLinhaDeletar("BE"+_Symbol+string(m_magic));
        HLinhaDeletar("TS"+_Symbol+string(m_magic));

      //+------------------------------------------------------------------+
      //| ROTEAMENTO DE COMPRA                                             |
      //+------------------------------------------------------------------+

        if((tendenciaAfastamento == a_favor_da_tendencia && candle[0].open < bufferAfastamentoSuperior[0] && SymbolInfoDouble(_Symbol, SYMBOL_ASK) >= bufferAfastamentoSuperior[0]) || (tendenciaAfastamento == contra_a_tendencia && candle[0].open > bufferAfastamentoInferior[0] && SymbolInfoDouble(_Symbol, SYMBOL_ASK) <= bufferAfastamentoInferior[0]))
        {
          double sl = 0.0;
          double tp = 0.0;

          if(InpStopLoss > 0) sl = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - ExtInpStopLoss);
          if(InpTakeProfit > 0) tp = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + ExtInpTakeProfit);

          OpenBuy(sl, tp);
        }

      //+------------------------------------------------------------------+
      //| ROTEAMENTO DE VENDA                                              |
      //+------------------------------------------------------------------+

        if((tendenciaAfastamento == a_favor_da_tendencia && candle[0].open > bufferAfastamentoInferior[0] && SymbolInfoDouble(_Symbol, SYMBOL_BID) <= bufferAfastamentoInferior[0]) || (tendenciaAfastamento == contra_a_tendencia && candle[0].open < bufferAfastamentoSuperior[0] && SymbolInfoDouble(_Symbol, SYMBOL_BID) >= bufferAfastamentoSuperior[0]))
        {
          double sl = 0.0;
          double tp = 0.0;

          if(InpStopLoss > 0) sl = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) + ExtInpStopLoss);
          if(InpTakeProfit > 0) tp = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) - ExtInpTakeProfit);

          OpenSell(sl, tp);
        }
   }

//+------------------------------------------------------------------+
//| FUNÇÃO DE COMPRAS E VENDAS - ESTRATÉGIA PRICE ACTION             |
//+------------------------------------------------------------------+

   void funcaoComprasEVendasPA()
   {
      //+------------------------------------------------------------------+
      //| COPPYBUFFER                                                      |
      //+------------------------------------------------------------------+

        CoppyBuffer();

      //+------------------------------------------------------------------+
      //| DELETA LINHAS                                                    |
      //+------------------------------------------------------------------+

        HLinhaDeletar("SL"+_Symbol+string(m_magic));
        HLinhaDeletar("TP"+_Symbol+string(m_magic));
        HLinhaDeletar("Entrada"+_Symbol+string(m_magic));
        HLinhaDeletar("BE"+_Symbol+string(m_magic));
        HLinhaDeletar("TS"+_Symbol+string(m_magic));

      //+------------------------------------------------------------------+
      //| TAMANHO DA VELA ANTERIOR                                         |
      //+------------------------------------------------------------------+

        double tamanho = m_symbol.NormalizePrice(candle[1].high - candle[1].low);

      //+------------------------------------------------------------------+
      //| ROTEAMENTO DE COMPRA                                             |
      //+------------------------------------------------------------------+

        if(tamanho >= ExtTamanhoMaximoDaVela)
        if((tendenciaPriceAction == a_favor_da_tendencia && SymbolInfoDouble(_Symbol, SYMBOL_ASK) >= m_symbol.NormalizePrice(candle[1].high + ExtPontosRompimento)) || (tendenciaPriceAction == contra_a_tendencia && SymbolInfoDouble(_Symbol, SYMBOL_ASK) <= m_symbol.NormalizePrice(candle[1].low - ExtPontosRompimento)))
        {
          double sl = 0.0;
          double tp = 0.0;

          if(InpStopLoss > 0) sl = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - ExtInpStopLoss);
          if(InpTakeProfit > 0) tp = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + ExtInpTakeProfit);

          OpenBuy(sl, tp);
        }

      //+------------------------------------------------------------------+
      //| ROTEAMENTO DE VENDA                                              |
      //+------------------------------------------------------------------+

        if(tamanho >= ExtTamanhoMaximoDaVela)
        if((tendenciaPriceAction == a_favor_da_tendencia && SymbolInfoDouble(_Symbol, SYMBOL_BID) <= m_symbol.NormalizePrice(candle[1].low - ExtPontosRompimento)) || (tendenciaPriceAction == contra_a_tendencia && SymbolInfoDouble(_Symbol, SYMBOL_BID) >= m_symbol.NormalizePrice(candle[1].high + ExtPontosRompimento)))
        {
          double sl = 0.0;
          double tp = 0.0;

          if(InpStopLoss > 0) sl = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) + ExtInpStopLoss);
          if(InpTakeProfit > 0) tp = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) - ExtInpTakeProfit);

          OpenSell(sl, tp);
        }
   }

//+------------------------------------------------------------------+
//| ENCERRA A POSIÇÃO QUANDO O HILO VIRA PARA O LADO OPOSTO         |
//+------------------------------------------------------------------+

   void funcaoEncerrarOperacaoViradaHiLo()
   {
      CoppyBuffer();

      if(ArraySize(candle) < 3 || ArraySize(bufferHiLoHigh) < 3 || ArraySize(bufferHiLoLow) < 3)
         return;

      bool sinalCompra = (candle[2].close <= bufferHiLoHigh[2] &&
                          candle[1].close >  bufferHiLoHigh[1]);

      bool sinalVenda  = (candle[2].close >= bufferHiLoLow[2] &&
                          candle[1].close <  bufferHiLoLow[1]);

      // Comprado + virada de venda = zera
      if(comprado && !vendido && sinalVenda)
      {
         Print("Robot -> HiLo virou para VENDA. Encerrando posição comprada.");
         zerar();
         return;
      }

      // Vendido + virada de compra = zera
      if(vendido && !comprado && sinalCompra)
      {
         Print("Robot -> HiLo virou para COMPRA. Encerrando posição vendida.");
         zerar();
         return;
      }
   }

//+------------------------------------------------------------------+
//| FUNÇÃO DE COMPRAS E VENDAS - VIRADA DE HILO                     |
//+------------------------------------------------------------------+

   void funcaoComprasEVendasHiLo()
   {
      CoppyBuffer();

      if(ArraySize(candle) < 3 || ArraySize(bufferHiLoHigh) < 3 || ArraySize(bufferHiLoLow) < 3)
         return;

      HLinhaDeletar("SL"+_Symbol+string(m_magic));
      HLinhaDeletar("TP"+_Symbol+string(m_magic));
      HLinhaDeletar("Entrada"+_Symbol+string(m_magic));
      HLinhaDeletar("BE"+_Symbol+string(m_magic));
      HLinhaDeletar("TS"+_Symbol+string(m_magic));

      // A virada é confirmada usando candles fechados:
      // COMPRA: fechamento anterior cruza acima da média das máximas.
      // VENDA : fechamento anterior cruza abaixo da média das mínimas.
      bool sinalCompra = (candle[2].close <= bufferHiLoHigh[2] &&
                          candle[1].close >  bufferHiLoHigh[1]);

      bool sinalVenda  = (candle[2].close >= bufferHiLoLow[2] &&
                          candle[1].close <  bufferHiLoLow[1]);

      if(sinalCompra)
      {
         double sl = 0.0;
         double tp = 0.0;

         if(InpStopLoss > 0)
            sl = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - ExtInpStopLoss);

         if(InpTakeProfit > 0)
            tp = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + ExtInpTakeProfit);

         OpenBuy(sl, tp);
         return;
      }

      if(sinalVenda)
      {
         double sl = 0.0;
         double tp = 0.0;

         if(InpStopLoss > 0)
            sl = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) + ExtInpStopLoss);

         if(InpTakeProfit > 0)
            tp = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) - ExtInpTakeProfit);

         OpenSell(sl, tp);
      }
   }

//+------------------------------------------------------------------+
//| FUNÇÃO DE COMPRAS E VENDAS - NEXUS ZONAS                         |
//| ATENÇÃO: indicador de terceiros (.ex5 compilado, sem fonte       |
//| disponível). O sinal usa a CONVENÇÃO buffer 0 = seta de compra / |
//| buffer 1 = seta de venda (valor != EMPTY_VALUE na barra fechada  |
//| = sinal). Essa convenção NÃO foi confirmada com o autor do       |
//| indicador - valide visualmente no gráfico antes de usar em conta |
//| real.                                                             |
//+------------------------------------------------------------------+

   void funcaoComprasEVendasNexusZonas()
   {
      CoppyBuffer();

      int idx = (confirmacaoNexusZonas == com_confirmacao) ? 1 : 0;

      if(ArraySize(bufferNexusZonasCompra) <= idx || ArraySize(bufferNexusZonasVenda) <= idx)
         return;

      HLinhaDeletar("SL"+_Symbol+string(m_magic));
      HLinhaDeletar("TP"+_Symbol+string(m_magic));
      HLinhaDeletar("Entrada"+_Symbol+string(m_magic));
      HLinhaDeletar("BE"+_Symbol+string(m_magic));
      HLinhaDeletar("TS"+_Symbol+string(m_magic));

      bool sinalCompra = (bufferNexusZonasCompra[idx] != EMPTY_VALUE && bufferNexusZonasCompra[idx] != 0.0);
      bool sinalVenda  = (bufferNexusZonasVenda[idx]  != EMPTY_VALUE && bufferNexusZonasVenda[idx]  != 0.0);

      if((tendenciaNexusZonas == a_favor_da_tendencia && sinalCompra) || (tendenciaNexusZonas == contra_a_tendencia && sinalVenda))
      {
         double sl = 0.0;
         double tp = 0.0;

         if(InpStopLoss > 0) sl = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - ExtInpStopLoss);
         if(InpTakeProfit > 0) tp = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + ExtInpTakeProfit);

         OpenBuy(sl, tp);
         return;
      }

      if((tendenciaNexusZonas == a_favor_da_tendencia && sinalVenda) || (tendenciaNexusZonas == contra_a_tendencia && sinalCompra))
      {
         double sl = 0.0;
         double tp = 0.0;

         if(InpStopLoss > 0) sl = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) + ExtInpStopLoss);
         if(InpTakeProfit > 0) tp = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) - ExtInpTakeProfit);

         OpenSell(sl, tp);
      }
   }

//+------------------------------------------------------------------+
//| FUNÇÃO DE COMPRAS E VENDAS - VPRANGE (VOLUME PROFILE)            |
//| ATENÇÃO: mesma ressalva da função NEXUS ZONAS acima.             |
//+------------------------------------------------------------------+

   void funcaoComprasEVendasVPRange()
   {
      CoppyBuffer();

      int idx = (confirmacaoVPRange == com_confirmacao) ? 1 : 0;

      if(ArraySize(bufferVPRangeCompra) <= idx || ArraySize(bufferVPRangeVenda) <= idx)
         return;

      HLinhaDeletar("SL"+_Symbol+string(m_magic));
      HLinhaDeletar("TP"+_Symbol+string(m_magic));
      HLinhaDeletar("Entrada"+_Symbol+string(m_magic));
      HLinhaDeletar("BE"+_Symbol+string(m_magic));
      HLinhaDeletar("TS"+_Symbol+string(m_magic));

      bool sinalCompra = (bufferVPRangeCompra[idx] != EMPTY_VALUE && bufferVPRangeCompra[idx] != 0.0);
      bool sinalVenda  = (bufferVPRangeVenda[idx]  != EMPTY_VALUE && bufferVPRangeVenda[idx]  != 0.0);

      if((tendenciaVPRange == a_favor_da_tendencia && sinalCompra) || (tendenciaVPRange == contra_a_tendencia && sinalVenda))
      {
         double sl = 0.0;
         double tp = 0.0;

         if(InpStopLoss > 0) sl = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - ExtInpStopLoss);
         if(InpTakeProfit > 0) tp = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + ExtInpTakeProfit);

         OpenBuy(sl, tp);
         return;
      }

      if((tendenciaVPRange == a_favor_da_tendencia && sinalVenda) || (tendenciaVPRange == contra_a_tendencia && sinalCompra))
      {
         double sl = 0.0;
         double tp = 0.0;

         if(InpStopLoss > 0) sl = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) + ExtInpStopLoss);
         if(InpTakeProfit > 0) tp = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) - ExtInpTakeProfit);

         OpenSell(sl, tp);
      }
   }

//+------------------------------------------------------------------+
//| FUNÇÃO DE COMPRAS E VENDAS - SUPPORT RESISTANCE REJECTION PRO    |
//| ATENÇÃO: mesma ressalva da função NEXUS ZONAS acima.             |
//+------------------------------------------------------------------+

   void funcaoComprasEVendasSRRejection()
   {
      CoppyBuffer();

      int idx = (confirmacaoSRRejection == com_confirmacao) ? 1 : 0;

      if(ArraySize(bufferSRRejectionCompra) <= idx || ArraySize(bufferSRRejectionVenda) <= idx)
         return;

      HLinhaDeletar("SL"+_Symbol+string(m_magic));
      HLinhaDeletar("TP"+_Symbol+string(m_magic));
      HLinhaDeletar("Entrada"+_Symbol+string(m_magic));
      HLinhaDeletar("BE"+_Symbol+string(m_magic));
      HLinhaDeletar("TS"+_Symbol+string(m_magic));

      bool sinalCompra = (bufferSRRejectionCompra[idx] != EMPTY_VALUE && bufferSRRejectionCompra[idx] != 0.0);
      bool sinalVenda  = (bufferSRRejectionVenda[idx]  != EMPTY_VALUE && bufferSRRejectionVenda[idx]  != 0.0);

      if((tendenciaSRRejection == a_favor_da_tendencia && sinalCompra) || (tendenciaSRRejection == contra_a_tendencia && sinalVenda))
      {
         double sl = 0.0;
         double tp = 0.0;

         if(InpStopLoss > 0) sl = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - ExtInpStopLoss);
         if(InpTakeProfit > 0) tp = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + ExtInpTakeProfit);

         OpenBuy(sl, tp);
         return;
      }

      if((tendenciaSRRejection == a_favor_da_tendencia && sinalVenda) || (tendenciaSRRejection == contra_a_tendencia && sinalCompra))
      {
         double sl = 0.0;
         double tp = 0.0;

         if(InpStopLoss > 0) sl = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) + ExtInpStopLoss);
         if(InpTakeProfit > 0) tp = m_symbol.NormalizePrice(SymbolInfoDouble(_Symbol, SYMBOL_BID) - ExtInpTakeProfit);

         OpenSell(sl, tp);
      }
   }


//+------------------------------------------------------------------+
//| LIMPA OBJETOS VISUAIS DO HILO                                   |
//+------------------------------------------------------------------+

   void LimpaVisualHiLo()
   {
      string prefixo = "ORION_HILO_"+_Symbol+"_"+string(m_magic)+"_";

      for(int i=ObjectsTotal(0,0,-1)-1; i>=0; i--)
      {
         string nome = ObjectName(0,i,0,-1);
         if(StringFind(nome,prefixo) == 0)
            ObjectDelete(0,nome);
      }
   }

//+------------------------------------------------------------------+
//| DESENHA O HILO ACTIVATOR NO GRÁFICO                             |
//| Alta  = média das mínimas                                        |
//| Baixa = média das máximas                                        |
//+------------------------------------------------------------------+

   void AtualizaVisualHiLo()
   {
      if(estrategia != estrategia_virada_hilo)
         return;

      if(exibirHiLoNoGrafico == nao)
      {
         LimpaVisualHiLo();
         return;
      }

      int quantidade = barrasHistoricoHiLo;
      if(quantidade < 20) quantidade = 20;
      if(quantidade > 1500) quantidade = 1500;

      MqlRates ratesHilo[];
      double maHigh[];
      double maLow[];

      ArraySetAsSeries(ratesHilo,true);
      ArraySetAsSeries(maHigh,true);
      ArraySetAsSeries(maLow,true);

      int copiadoRates = CopyRates(_Symbol,ENUM_TIMEFRAMES(tempoGrafico),0,quantidade+2,ratesHilo);
      int copiadoHigh  = CopyBuffer(handleHiLoHigh,0,0,quantidade+2,maHigh);
      int copiadoLow   = CopyBuffer(handleHiLoLow,0,0,quantidade+2,maLow);

      int total = MathMin(copiadoRates,MathMin(copiadoHigh,copiadoLow));
      if(total < InpPeriodHilo+3)
         return;

      LimpaVisualHiLo();

      // Estado: 1 = alta / compra, -1 = baixa / venda.
      // Começamos pela barra mais antiga e mantemos o estado
      // enquanto o preço permanecer entre as duas referências.
      int estado = 0;
      string prefixo = "ORION_HILO_"+_Symbol+"_"+string(m_magic)+"_";

      for(int i=total-2; i>=1; i--)
      {
         if(ratesHilo[i].close > maHigh[i])
            estado = 1;
         else if(ratesHilo[i].close < maLow[i])
            estado = -1;

         if(estado == 0)
            continue;

         double valor1 = (estado == 1 ? maLow[i+1] : maHigh[i+1]);
         double valor2 = (estado == 1 ? maLow[i]   : maHigh[i]);

         string nome = prefixo + IntegerToString(i);

         if(ObjectCreate(0,nome,OBJ_TREND,0,
                         ratesHilo[i+1].time,valor1,
                         ratesHilo[i].time,valor2))
         {
            ObjectSetInteger(0,nome,OBJPROP_RAY_RIGHT,false);
            ObjectSetInteger(0,nome,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,nome,OBJPROP_SELECTED,false);
            ObjectSetInteger(0,nome,OBJPROP_BACK,false);
            ObjectSetInteger(0,nome,OBJPROP_HIDDEN,true);

            if(estado == 1)
            {
               ObjectSetInteger(0,nome,OBJPROP_COLOR,corCompraHilo);
               ObjectSetInteger(0,nome,OBJPROP_WIDTH,espessuraCompraHilo);
            }
            else
            {
               ObjectSetInteger(0,nome,OBJPROP_COLOR,corVendaHilo);
               ObjectSetInteger(0,nome,OBJPROP_WIDTH,espessuraVendaHilo);
            }
         }
      }

      ChartRedraw(0);
   }

//+------------------------------------------------------------------+
//| COPYBUFFER                                                       |
//+------------------------------------------------------------------+

 void CoppyBuffer()
 {

   //+------------------------------------------------------------------+
   //| COPYRATES DO CANDLE                                              |
   //+------------------------------------------------------------------+

     if(CopyRates(_Symbol, ENUM_TIMEFRAMES(tempoGrafico), 0, 5, candle) < 0)
     {
       Print("Robot -> Erro ao obter as informações do MqlRates do Candle: ",GetLastError());
       return;
     }

   //+------------------------------------------------------------------+
   //| COPPYBUFFER DO INDICADOR BANDAS DE BOLLINGER                     |
   //+------------------------------------------------------------------+

     if(estrategia == estrategia_bb)
     {
        if(CopyBuffer(handleBB, 0, 0, 3, bufferBBSuperior)<0)
        {
          Print("Robot -> Erro ao copiar dados do indicador BANDAS DE BOLLINGER: ",GetLastError());
          return;
        }

        //---

        if(CopyBuffer(handleBB, 1, 0, 3, bufferBBInferior)<0)
        {
          Print("Robot -> Erro ao copiar dados do indicador BANDAS DE BOLLINGER: ",GetLastError());
          return;
        }
     }

   //+------------------------------------------------------------------+
   //| COPPYBUFFER DO INDICADOR CRUZAMENTO DE DUAS MÉDIAS MÓVEIS        |
   //+------------------------------------------------------------------+

     if(estrategia == estrategia_cruzamento_de_medias)
     {
        if(CopyBuffer(handleMM01, 0, 0, 3, bufferMM01)<0)
        {
          Print("Robot -> Erro ao copiar dados do indicador MÉDIA MÓVEL 01: ",GetLastError());
          return;
        }

        //---

        if(CopyBuffer(handleMM02, 0, 0, 3, bufferMM02)<0)
        {
          Print("Robot -> Erro ao copiar dados do indicador MÉDIA MÓVEL 02: ",GetLastError());
          return;
        }
     }

   //+------------------------------------------------------------------+
   //| COPPYBUFFER DO INDICADOR AFASTAMENTO DE MÉDIA                    |
   //+------------------------------------------------------------------+

     if(estrategia == estrategia_afastamento_de_media)
     {
        if(CopyBuffer(handleAfastamento, 0, 0, 3, bufferAfastamentoSuperior)<0)
        {
          Print("Robot -> Erro ao copiar dados do indicador AFASTAMENTO DE MÉDIA: ",GetLastError());
          return;
        }

        //---

        if(CopyBuffer(handleAfastamento, 1, 0, 3, bufferAfastamentoCentral)<0)
        {
          Print("Robot -> Erro ao copiar dados do indicador AFASTAMENTO DE MÉDIA: ",GetLastError());
          return;
        }

        //---

        if(CopyBuffer(handleAfastamento, 2, 0, 3, bufferAfastamentoInferior)<0)
        {
          Print("Robot -> Erro ao copiar dados do indicador AFASTAMENTO DE MÉDIA: ",GetLastError());
          return;
        }
     }

   //+------------------------------------------------------------------+
   //| COPPYBUFFER DO INDICADOR VIRADA DE HILO                          |
   //+------------------------------------------------------------------+
   //| CORREÇÃO: sem este bloco, bufferHiLoHigh/bufferHiLoLow nunca são |
   //| preenchidos e a estratégia HiLo nunca gera sinal de entrada.     |
   //+------------------------------------------------------------------+

     if(estrategia == estrategia_virada_hilo)
     {
        if(CopyBuffer(handleHiLoHigh, 0, 0, 3, bufferHiLoHigh)<0)
        {
          Print("Robot -> Erro ao copiar dados do indicador HILO (Máximas): ",GetLastError());
          return;
        }

        //---

        if(CopyBuffer(handleHiLoLow, 0, 0, 3, bufferHiLoLow)<0)
        {
          Print("Robot -> Erro ao copiar dados do indicador HILO (Mínimas): ",GetLastError());
          return;
        }
     }

   //+------------------------------------------------------------------+
   //| COPPYBUFFER DO INDICADOR NEXUS ZONAS                             |
   //+------------------------------------------------------------------+

     if(estrategia == estrategia_nexus_zonas)
     {
        if(CopyBuffer(handleNexusZonas, 0, 0, 3, bufferNexusZonasCompra)<0)
        {
          Print("Robot -> Erro ao copiar dados do indicador NEXUS ZONAS: ",GetLastError());
          return;
        }

        //---

        if(CopyBuffer(handleNexusZonas, 1, 0, 3, bufferNexusZonasVenda)<0)
        {
          Print("Robot -> Erro ao copiar dados do indicador NEXUS ZONAS: ",GetLastError());
          return;
        }
     }

   //+------------------------------------------------------------------+
   //| COPPYBUFFER DO INDICADOR VPRANGE (VOLUME PROFILE)                |
   //+------------------------------------------------------------------+

     if(estrategia == estrategia_vprange)
     {
        if(CopyBuffer(handleVPRange, 0, 0, 3, bufferVPRangeCompra)<0)
        {
          Print("Robot -> Erro ao copiar dados do indicador VPRANGE: ",GetLastError());
          return;
        }

        //---

        if(CopyBuffer(handleVPRange, 1, 0, 3, bufferVPRangeVenda)<0)
        {
          Print("Robot -> Erro ao copiar dados do indicador VPRANGE: ",GetLastError());
          return;
        }
     }

   //+------------------------------------------------------------------+
   //| COPPYBUFFER DO INDICADOR SUPPORT RESISTANCE REJECTION PRO        |
   //+------------------------------------------------------------------+

     if(estrategia == estrategia_sr_rejection)
     {
        if(CopyBuffer(handleSRRejection, 0, 0, 3, bufferSRRejectionCompra)<0)
        {
          Print("Robot -> Erro ao copiar dados do indicador SUPPORT RESISTANCE REJECTION PRO: ",GetLastError());
          return;
        }

        //---

        if(CopyBuffer(handleSRRejection, 1, 0, 3, bufferSRRejectionVenda)<0)
        {
          Print("Robot -> Erro ao copiar dados do indicador SUPPORT RESISTANCE REJECTION PRO: ",GetLastError());
          return;
        }
     }
 }

//+------------------------------------------------------------------+
//| COLOCA  AS SETAS DE NEGOCIAÇÃO ATRÁS DO GRÁFICO                  |
//+------------------------------------------------------------------+

 void ObjectsArrowToBack()
 {
   static int totalLast = 0;
   int total = ObjectsTotal(0);
   if (total == totalLast) return;
   totalLast = total;
   for(int i = total - 1; i >= 0; i--)
   {
      if(StringFind(ObjectName(0, i), "#") >= 0)
      {
         ObjectSetInteger(0, ObjectName(0, i), OBJPROP_BACK, true);
      }
   }
 }

//+------------------------------------------------------------------+
//| DEFINE O TEMPLATE DO GRÁFICO                                     |
//+------------------------------------------------------------------+

bool ChartDefines(const bool value,const long chart_ID=0)
  {
//--- Resetar Ultimo Erro
   ResetLastError();

//--- Definir Exibição Do Grid
   if(!ChartSetInteger(chart_ID,CHART_SHOW_GRID,0,gradeDoGrafico))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }

//--- Definir Exibição Do de ask
   if(!ChartSetInteger(chart_ID,CHART_SHOW_ASK_LINE,0,linhaAskDoGrafico))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }

//--- Definir cor da Linha Ask
   if(!ChartSetInteger(chart_ID,CHART_COLOR_ASK,corDaLinhaAsk))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }

//--- Definir Exibição Do de bid
   if(!ChartSetInteger(chart_ID,CHART_SHOW_BID_LINE,0,linhaBidDoGrafico))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }

//--- Definir cor da Linha bid
   if(!ChartSetInteger(chart_ID,CHART_COLOR_BID,corDaLinhaBid))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }

//--- Definir cor da linha do ultimo Preço
   if(!ChartSetInteger(chart_ID,CHART_SHOW_LAST_LINE,linhaLastDoGrafico))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }
//--- Definir cor da linha do ultimo Preço
   if(!ChartSetInteger(chart_ID,CHART_COLOR_LAST,corDaLinhaLast))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }

//--- Definir cor do Primeiro Plano
   if(!ChartSetInteger(chart_ID,CHART_COLOR_FOREGROUND,corDoPrimeiroPlano))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }

//--- Definir cor Do Fundo
   if(!ChartSetInteger(chart_ID,CHART_COLOR_BACKGROUND,corDoFundoDoGrafico))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }
//--- Definir cor Da Grade
   if(!ChartSetInteger(chart_ID,CHART_COLOR_GRID,corDaGradeDoGrafico))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }

//--- Definir cor Do Candle De Alta
   if(!ChartSetInteger(chart_ID,CHART_COLOR_CANDLE_BULL,corDoCandleDeAlta))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }

//--- Definir cor da Barra de Alta
   if(!ChartSetInteger(chart_ID,CHART_COLOR_CHART_UP,corDaBarraDeAlta))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }

//--- Definir cor da Barra de baixa
   if(!ChartSetInteger(chart_ID,CHART_COLOR_CHART_DOWN,corDaBarraDeBaixa))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }

//--- Definir cor do Candle de Baixa
   if(!ChartSetInteger(chart_ID,CHART_COLOR_CANDLE_BEAR,corDoCandleDeBaixa))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }

     //---

     if(!ChartSetInteger(chart_ID,CHART_SHOW_TICKER,false))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }

     //---

     if(!ChartSetInteger(chart_ID,CHART_SHOW_ONE_CLICK,false))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }

     //---

     if(!ChartSetInteger(chart_ID,CHART_SHOW_PERIOD_SEP,true))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }

     //---

     if(!ChartSetInteger(chart_ID,CHART_SHOW_VOLUMES,false))
     {
      //--- Caso Der Erro Exibilo
      Print(__FUNCTION__+", Robot -> Error Code = ",GetLastError());
      return(false);
     }

//---
   return(true);
  }

//+------------------------------------------------------------------+
//| DEFINE O TIPO DE GRÁFICO                                         |
//+------------------------------------------------------------------+

bool ChartModeSet(const long value,const long chart_ID=0)
  {
//--- redefine o valor de erro
   ResetLastError();
//--- define valor de propriedade
   if(!ChartSetInteger(chart_ID,CHART_MODE,value))
     {
      //--- exibe uma mensagem para o diário Experts
      Print(__FUNCTION__+", Robot -> Código de erro = ",GetLastError());
      return(false);
     }
//--- sucesso na execução
   return(true);
  }

//+------------------------------------------------------------------+
//| ESCALA DO GRÁFICO                                                |
//+------------------------------------------------------------------+

bool ChartScaleSet(const long value,const long chart_ID=0)
  {
//--- redefine o valor de erro
   ResetLastError();
//--- define valor de propriedade
   if(!ChartSetInteger(chart_ID,CHART_SCALE,0,value))
     {
      //--- exibe uma mensagem para o diário Experts
      Print(__FUNCTION__+", Robot -> Código de erro = ",GetLastError());
      return(false);
     }
//--- sucesso na execução
   return(true);
  }

//+------------------------------------------------------------------+
//| VALIDADE DO VOLUME                                               |
//+------------------------------------------------------------------+

bool CheckVolumeValue(double volume,string &description)
  {
   double min_volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   if(volume<min_volume)
   {
      description=StringFormat("Robot -> Volume é menor que o mínimo permitido SYMBOL_VOLUME_MIN=%.2f",min_volume);
      return(false);
   }

   double max_volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   if(volume>max_volume)
   {
      description=StringFormat("Robot -> Volume é maior que o máximo permitido SYMBOL_VOLUME_MAX=%.2f",max_volume);
      return(false);
   }

   return(true);
  }

//+------------------------------------------------------------------+
//| FUNÇÃO DE COMPRA                                                 |
//+------------------------------------------------------------------+

  void OpenBuy(double sl, double tp)
  {
    if(ComentarioPosicao() || ComentarioOrdemEntrada()) return;

    if(market_open(_Symbol))
    {
        PosicoesEOrdens();

        if(!posicaoAberta && !ordPendente && InpLot > 0 && TerminalInfoInteger(TERMINAL_CONNECTED) && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && AccountInfoInteger(ACCOUNT_TRADE_EXPERT) && MQLInfoInteger(MQL_TRADE_ALLOWED))
          if(m_trade.Buy(NormalizeVolume(InpLot), _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, tp, "C_Robot - " + _Symbol + " - " + string(m_magic)))
          {
            Print("Robot -> Ordem de compra executada com sucesso. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
            Sleep(2000);
            candle_operado = true;
            PosicoesEOrdens();
            return;
          }else Print("Robot -> Não foi possível executar a ordem de compra. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
    }else Print("Robot -> Não foi possível executar a ordem de compra, pois o mercado encontra-se fechado");
  }

//+------------------------------------------------------------------+
//| FUNÇÃO DE VENDA                                                  |
//+------------------------------------------------------------------+

  void OpenSell(double sl, double tp)
  {
    if(ComentarioPosicao() || ComentarioOrdemEntrada()) return;

    if(market_open(_Symbol))
    {
        PosicoesEOrdens();

        if(!posicaoAberta && !ordPendente && InpLot > 0 && TerminalInfoInteger(TERMINAL_CONNECTED) && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && AccountInfoInteger(ACCOUNT_TRADE_EXPERT) && MQLInfoInteger(MQL_TRADE_ALLOWED))
          if(m_trade.Sell(NormalizeVolume(InpLot), _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), sl, tp, "V_Robot - " + _Symbol + " - " + string(m_magic)))
          {
            Print("Robot -> Ordem de venda executada com sucesso. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
            Sleep(2000);
            candle_operado = true;
            PosicoesEOrdens();
            return;
          }else Print("Robot -> Não foi possível executar a ordem de venda. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
    }else Print("Robot -> Não foi possível executar a ordem de venda, pois o mercado encontra-se fechado");
  }

//+------------------------------------------------------------------+
//| VERIFICA SE O MERCADO ESTÁ ABERTO                                |
//+------------------------------------------------------------------+

  bool market_open(string symbol)
  {
   if(StringLen(symbol) > 1)
   {
      datetime begin=0;
      datetime end=0;
      datetime now=TimeTradeServer();
      uint     session_index=0;

      MqlDateTime today;
      TimeToStruct(now,today);
      if(SymbolInfoSessionTrade(symbol,(ENUM_DAY_OF_WEEK) today.day_of_week,session_index,begin,end)==true)
      {
         string snow=TimeToString(now,TIME_MINUTES|TIME_SECONDS);
         string sbegin=TimeToString(begin,TIME_MINUTES|TIME_SECONDS);
         string send=TimeToString(end-1,TIME_MINUTES|TIME_SECONDS);

         now=StringToTime(snow);
         begin=StringToTime(sbegin);
         end=StringToTime(send);

         if(now>=begin && now<=end)
            return true;

         return false;
      }
      else return false;
   }
   Print("Robot -> Ativo Inválido!");
   return false;
  }

//+------------------------------------------------------------------+
//| DELETA ORDENS PENDENTES                                          |
//+------------------------------------------------------------------+

  void DeletaOrdens()
  {
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(OrderGetTicket(i))) continue;

      ulong ticket=OrderGetTicket(i);
      string symbol=OrderGetString(ORDER_SYMBOL);
      ulong magic = OrderGetInteger(ORDER_MAGIC);

      if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && ticket > 0 && symbol == _Symbol)
      {
         int contador = 0;
         do
          {
            if(OrderSelect(OrderGetTicket(i)))
              if(m_trade.OrderDelete(ticket))
              {
                Print("Robot -> Ordem deletada com sucesso. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                break;
              }else Print("Robot -> Não foi possível deletar a ordem. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
              Sleep(20);
              contador++;
          }while(contador <= 5);
      }
   }
 }

//+------------------------------------------------------------------------------+
//| META FINANCEIRA DIÁRIA                                                       |
//+------------------------------------------------------------------------------+

void funcao_verifica_meta_ou_perda_atingida()
  {
   double soma_lucro = 0.0;
   int trade_positivo = 0;
   int contador_trades = 0;

   HistorySelect(StringToTime(hoje+" 00:00"),TimeCurrent());

   int total = HistoryDealsTotal();
   for(int i=0; i<total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      long Entry  = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      ulong magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);

      if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && ticket > 0 && HistoryDealGetString(ticket,DEAL_SYMBOL) == _Symbol)
         soma_lucro += HistoryDealGetDouble(ticket, DEAL_PROFIT);

      if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && ticket > 0 && HistoryDealGetString(ticket,DEAL_SYMBOL) == _Symbol && HistoryDealGetDouble(ticket, DEAL_PROFIT) > 0)
         trade_positivo++;

      if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && HistoryDealGetString(ticket,DEAL_SYMBOL) == _Symbol && ((HistoryDealGetDouble(ticket, DEAL_PROFIT) < 0) || (HistoryDealGetDouble(ticket, DEAL_PROFIT) > 0)))
         contador_trades++;
   }

   //---

     pos_price = soma_lucro;

   //---

   pos_trades = contador_trades;
   trades_positivos = trade_positivo;

   if(trade_positivo > 0)
      porcentagemAcertos  = (100 * trade_positivo) / contador_trades;
   else porcentagemAcertos = 0;
 }

//+----------------------------------------------------------------------------------+
//| META FINANCEIRA SEMANAL                                                          |
//+----------------------------------------------------------------------------------+

void funcao_verifica_meta_ou_perda_atingida_semana()
  {
   double soma_lucro=0;
   double pos_lucro_semana = 0;
   double pos_prejuizo_semana = 0;
   int trade_positivo_semana = 0;
   int contador_trades_semana = 0;
   string ativo = "";

   if(CopyRates(_Symbol, ENUM_TIMEFRAMES(PERIOD_W1), 0, 1, candleSemana)<0)
   {
      Print("Robot -> Erro ao obter as informações de MqlRates: ",GetLastError());
      return;
   }

   HistorySelect(candleSemana[0].time, TimeCurrent());

   int total = HistoryDealsTotal();
   for(int i=0; i<total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      string simbolo = HistoryDealGetString(ticket,DEAL_SYMBOL);
      ulong magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      long Entry  = HistoryDealGetInteger(ticket, DEAL_ENTRY);

      if((ligarMetas == Desligado && simbolo == _Symbol) || (ligarMetas == Ligado && StringFind(simbolo, letras, 0) != -1))
      if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && ticket > 0)
         soma_lucro += HistoryDealGetDouble(ticket, DEAL_PROFIT);

      //---

      if((ligarMetas == Desligado && simbolo == _Symbol) || (ligarMetas == Ligado && StringFind(simbolo, letras, 0) != -1))
      if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && ticket > 0 && HistoryDealGetDouble(ticket, DEAL_PROFIT) > 0)
      {
         pos_lucro_semana += HistoryDealGetDouble(ticket, DEAL_PROFIT);
         trade_positivo_semana++;
      }

      //---

      if((ligarMetas == Desligado && simbolo == _Symbol) || (ligarMetas == Ligado && StringFind(simbolo, letras, 0) != -1))
      if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && ticket > 0 && HistoryDealGetDouble(ticket, DEAL_PROFIT) < 0)
         pos_prejuizo_semana += HistoryDealGetDouble(ticket, DEAL_PROFIT);

      //---

      if((ligarMetas == Desligado && simbolo == _Symbol) || (ligarMetas == Ligado && StringFind(simbolo, letras, 0) != -1))
      if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && ((HistoryDealGetDouble(ticket, DEAL_PROFIT) < 0) || (HistoryDealGetDouble(ticket, DEAL_PROFIT) > 0)))
         contador_trades_semana++;

   }

    //---

    pos_price_semana = pos_lucro_semana + pos_prejuizo_semana;

    pos_trades_semana = contador_trades_semana;
    trades_positivos_semana = trade_positivo_semana;

    if(trade_positivo_semana > 0)
       porcentagemAcertos_semana  = (100 * trade_positivo_semana) / contador_trades_semana;
    else porcentagemAcertos_semana = 0;

 }

//+------------------------------------------------------------------------------+
//| META FINANCEIRA MENSAL                                                       |
//+------------------------------------------------------------------------------+

void funcao_verifica_meta_ou_perda_atingida_mes()
  {

   double soma_lucro=0;
   double pos_lucro_mes = 0;
   double pos_prejuizo_mes = 0;
   int trade_positivo_mes = 0;
   int contador_trades_mes = 0;
   string ativo = "";

   MqlDateTime str1;
   diaAtual = TimeCurrent();
   TimeToStruct(diaAtual,str1);
   int ano = str1.year;
   int mes = str1.mon;

   HistorySelect(StringToTime(IntegerToString(ano) + "." + IntegerToString(mes) + "." + "01 00:00"), StringToTime(IntegerToString(ano) + "." + IntegerToString(mes) + "." + "31 23:59:59"));

   int total = HistoryDealsTotal();
   for(int i=0; i<total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      string simbolo = HistoryDealGetString(ticket,DEAL_SYMBOL);
      ulong magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      long Entry  = HistoryDealGetInteger(ticket, DEAL_ENTRY);

      if((ligarMetas == Desligado && simbolo == _Symbol) || (ligarMetas == Ligado && StringFind(simbolo, letras, 0) != -1))
      if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && ticket > 0)
         soma_lucro += HistoryDealGetDouble(ticket, DEAL_PROFIT);

      //---

      if((ligarMetas == Desligado && simbolo == _Symbol) || (ligarMetas == Ligado && StringFind(simbolo, letras, 0) != -1))
      if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && ticket > 0 && HistoryDealGetDouble(ticket, DEAL_PROFIT) > 0)
      {
         pos_lucro_mes += HistoryDealGetDouble(ticket, DEAL_PROFIT);
         trade_positivo_mes++;
      }

      //---


      if((ligarMetas == Desligado && simbolo == _Symbol) || (ligarMetas == Ligado && StringFind(simbolo, letras, 0) != -1))
      if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && ticket > 0 && HistoryDealGetDouble(ticket, DEAL_PROFIT) < 0)
         pos_prejuizo_mes += HistoryDealGetDouble(ticket, DEAL_PROFIT);

      //---

      if((ligarMetas == Desligado && simbolo == _Symbol) || (ligarMetas == Ligado && StringFind(simbolo, letras, 0) != -1))
      if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && ((HistoryDealGetDouble(ticket, DEAL_PROFIT) < 0) || (HistoryDealGetDouble(ticket, DEAL_PROFIT) > 0)))
         contador_trades_mes++;

   }

   //---

   pos_price_mes = pos_lucro_mes + pos_prejuizo_mes;

   pos_trades_mes = contador_trades_mes;
   trades_positivos_mes = trade_positivo_mes;

   if(trade_positivo_mes > 0)
      porcentagemAcertos_mes  = (100 * trade_positivo_mes) / contador_trades_mes;
   else porcentagemAcertos_mes = 0;
 }

//+------------------------------------------------------------------+
//| ZERA TODAS AS POSIÇÕES ABERTAS                                   |
//+------------------------------------------------------------------+

void zerar()
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(m_position.SelectByIndex(i))
         if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && m_position.Magic() == m_magic)) && m_position.Symbol() == Symbol())
           {
            int contador = 0;
            do{
                if(m_position.SelectByIndex(i))
                  if(m_trade.PositionClose(m_position.Ticket(), 0))
                  {
                    Print("Robot -> Posição zerada com sucesso. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                    break;
                  }else Print("Robot -> Não foi possível zerar a posição. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                  Sleep(20);
                  contador++;
              }while(contador<=20);
          }

  }

//+------------------------------------------------------------------+
//| CRIA LINHA HORIZONTAL                                            |
//+------------------------------------------------------------------+

bool HLinhaCriar(string name, double price, string txt, color clr, color clrTexto, int horizontal)
  {
//---
   if(!ObjectCreate(0,name, OBJ_HLINE, 0, 0, price))
      return(false);

//---
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASHDOT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);

//---
   int x, y;
   ChartTimePriceToXY(0, 0, TimeCurrent(), price, x, y);

//---
   if(!ObjectCreate(0,name+"R", OBJ_RECTANGLE_LABEL, 0, 0, 0))
      return(false);

   ObjectSetInteger(0, name+"R", OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name+"R", OBJPROP_XDISTANCE, horizontal);
   ObjectSetInteger(0, name+"R", OBJPROP_YDISTANCE, y-10);
   ObjectSetInteger(0, name+"R", OBJPROP_XSIZE, horizontal);
   ObjectSetInteger(0, name+"R", OBJPROP_YSIZE, 17);

   ObjectSetInteger(0, name+"R", OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, name+"R", OBJPROP_BORDER_TYPE, BORDER_SUNKEN);
   ObjectSetInteger(0, name+"R", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name+"R", OBJPROP_BORDER_COLOR, clr);
   ObjectSetInteger(0, name+"R", OBJPROP_BACK, false);

//---
   if(!ObjectCreate(0,name+"L", OBJ_LABEL, 0, 0, 0))
      return(false);

   ObjectSetInteger(0, name+"L", OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, name+"L", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name+"L", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, name+"L", OBJPROP_YDISTANCE, y-10);

   ObjectSetInteger(0, name+"L", OBJPROP_COLOR, clrTexto);
   ObjectSetInteger(0, name+"L", OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name+"L", OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name+"L", OBJPROP_BACK, false);

//--- sucesso na execução
   return(true);
  }

//+------------------------------------------------------------------+
//| CRIA LINHA HORIZONTAL SÓLIDA                                     |
//+------------------------------------------------------------------+

bool HLinhaCriarLinhaSolida(string name, double price, string txt, color clr, color clrTexto, int horizontal)
  {
//---
   if(!ObjectCreate(0,name, OBJ_HLINE, 0, 0, price))
      return(false);

//---
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);

//---
   int x, y;
   ChartTimePriceToXY(0, 0, TimeCurrent(), price, x, y);

//---
   if(!ObjectCreate(0,name+"R", OBJ_RECTANGLE_LABEL, 0, 0, 0))
      return(false);

   ObjectSetInteger(0, name+"R", OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name+"R", OBJPROP_XDISTANCE, horizontal);
   ObjectSetInteger(0, name+"R", OBJPROP_YDISTANCE, y-10);
   ObjectSetInteger(0, name+"R", OBJPROP_XSIZE, horizontal);
   ObjectSetInteger(0, name+"R", OBJPROP_YSIZE, 17);

   ObjectSetInteger(0, name+"R", OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, name+"R", OBJPROP_BORDER_TYPE, BORDER_SUNKEN);
   ObjectSetInteger(0, name+"R", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name+"R", OBJPROP_BORDER_COLOR, clr);
   ObjectSetInteger(0, name+"R", OBJPROP_BACK, false);

//---
   if(!ObjectCreate(0,name+"L", OBJ_LABEL, 0, 0, 0))
      return(false);

   ObjectSetInteger(0, name+"L", OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, name+"L", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name+"L", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, name+"L", OBJPROP_YDISTANCE, y-10);

   ObjectSetInteger(0, name+"L", OBJPROP_COLOR, clrTexto);
   ObjectSetInteger(0, name+"L", OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name+"L", OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name+"L", OBJPROP_BACK, false);

//--- sucesso na execução
   return(true);
  }

//+------------------------------------------------------------------+
//| DELETA LINHA HORIZONTAL                                          |
//+------------------------------------------------------------------+

 bool HLinhaDeletar(string name)
  {
//---
   ObjectDelete(0,name);
   ObjectDelete(0,name+"R");
   ObjectDelete(0,name+"L");

//--- sucesso na execução
   return(true);
  }

//+------------------------------------------------------------------+
//| MOVE LINHA HORIZONTAL                                            |
//+------------------------------------------------------------------+

  bool HLinhaMover(string name, double price)
  {
   //---
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);

   int x, y;
   ChartTimePriceToXY(0, 0, TimeCurrent(), price, x, y);
   ObjectSetInteger(0, name+"R", OBJPROP_YDISTANCE, y-10);
   ObjectSetInteger(0, name+"L", OBJPROP_YDISTANCE, y-10);
   //--- sucesso na execução
   return(true);
  }

//+------------------------------------------------------------------+
//| MOVEL LINHA HORIZONTAL                                           |
//+------------------------------------------------------------------+

  bool HLinhaMoverEntrada(string name, double price)
  {
   //---
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);

   int x, y;
   ChartTimePriceToXY(0, 0, TimeCurrent(), price, x, y);
   ObjectSetInteger(0, name+"R", OBJPROP_YDISTANCE, y-10);
   ObjectSetInteger(0, name+"L", OBJPROP_YDISTANCE, y-10);
   ObjectSetString(0, name+"L", OBJPROP_TEXT, DoubleToString(lucroPosicoes, 2));

   if(lucroPosicoes >= 0)
   {
     ObjectSetInteger(0, name+"L", OBJPROP_COLOR, clrWhite);
     ObjectSetInteger(0, name+"R", OBJPROP_BGCOLOR, clrBlueViolet);
     ObjectSetInteger(0, name+"R", OBJPROP_BORDER_COLOR, clrBlueViolet);
   }else if(lucroPosicoes < 0)
         {
           ObjectSetInteger(0, name+"L", OBJPROP_COLOR, clrWhite);
           ObjectSetInteger(0, name+"R", OBJPROP_BGCOLOR, clrRed);
           ObjectSetInteger(0, name+"R", OBJPROP_BORDER_COLOR, clrRed);
         }

   //--- sucesso na execução
   return(true);
  }

//+------------------------------------------------------------------+
//| NORMALIZA O VOLUME                                               |
//+------------------------------------------------------------------+

   double NormalizeVolume(double volume)
   {
      static const double min  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
      static const double max  = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
      static const int digits  = (int)-
   MathLog10(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP));
      if (volume < min) volume = min;
      if (volume > max) volume = max;
      return NormalizeDouble(volume, digits);
   }

//+------------------------------------------------------------------+
//| POSIÇÃO ATUAL                                                    |
//+------------------------------------------------------------------+

  string PosicaoAtual()
  {
    posicaoAtual = "";

    if(comprado && !vendido)
      posicaoAtual = "Comprado";
    else if(vendido && !comprado)
           posicaoAtual = "Vendido";
         else if(!comprado && !vendido)
                posicaoAtual = "Zerado";

    return(posicaoAtual);
  }

//+------------------------------------------------------------------+
//| ATUALIZAÇÕES DO PAINEL 01                                        |
//+------------------------------------------------------------------+

  void UpdatePanel()
  {
    if(lucroPosicoes >= 0)
    {
      m_Texto27.Text("---> "+DoubleToString(lucroPosicoes, 2));
      m_Texto27.Color(clrLightGreen);
    }else{
           m_Texto27.Text("---> "+DoubleToString(lucroPosicoes, 2));
           m_Texto27.Color(clrOrangeRed);
         }

    //---

    m_Texto18.Text("---> "+DoubleToString(volumeDaPosicaoAberta, 2));
    m_Texto18.Color(clrWhite);

    //---

    m_Texto21.Text("---> "+TimeToString(TimeCurrent(), TIME_MINUTES|TIME_SECONDS));
    m_Texto21.Color(clrWhite);

    //---

    m_Texto25.Text("---> "+IntegerToString((PeriodSeconds(ENUM_TIMEFRAMES(tempoGrafico)) - (int(TimeCurrent()) % PeriodSeconds(ENUM_TIMEFRAMES(tempoGrafico))))) + " s");
    m_Texto25.Color(clrWhite);
  }

//+------------------------------------------------------------------+
//| ATUALIZAÇÕES DO PAINEL 02                                        |
//+------------------------------------------------------------------+

  void UpdatePanel02()
  {
    m_Texto16.Text("---> "+_Symbol);
    m_Texto16.Color(clrYellow);

    m_Texto17.Text("---> "+string(m_magic));
    m_Texto17.Color(clrYellow);

    m_Texto19.Text("---> "+TimeToString(TimeCurrent(), TIME_DATE));
    m_Texto19.Color(clrWhite);

    //---

    if(pos_price >= 0)
    {
      m_Texto28.Text("---> "+DoubleToString(pos_price, 2));
      m_Texto28.Color(clrLightGreen);
    }else{
           m_Texto28.Text("---> "+DoubleToString(pos_price, 2));
           m_Texto28.Color(clrOrangeRed);
         }

    //---

    if(pos_price_semana >= 0)
    {
      m_Texto29.Text("---> "+DoubleToString(pos_price_semana, 2));
      m_Texto29.Color(clrLightGreen);
    }else{
           m_Texto29.Text("---> "+DoubleToString(pos_price_semana, 2));
           m_Texto29.Color(clrOrangeRed);
         }

    //---

    if(pos_price_mes >= 0)
    {
      m_Texto30.Text("---> "+DoubleToString(pos_price_mes, 2));
      m_Texto30.Color(clrLightGreen);
    }else{
           m_Texto30.Text("---> "+DoubleToString(pos_price_mes, 2));
           m_Texto30.Color(clrOrangeRed);
         }

    //---

    m_Texto20.Text("---> "+posicaoAtual);
    m_Texto20.Color(clrWhite);

    m_Texto22.Text("---> "+IntegerToString(trades_positivos) + "/" + IntegerToString(pos_trades));
    m_Texto22.Color(clrWhite);

    m_Texto23.Text("---> "+IntegerToString(trades_positivos_semana) + "/" + IntegerToString(pos_trades_semana));
    m_Texto23.Color(clrWhite);

    m_Texto24.Text("---> "+IntegerToString(trades_positivos_mes) + "/" + IntegerToString(pos_trades_mes));
    m_Texto24.Color(clrWhite);

    m_Texto26.Text("---> "+metaDiaria);
    m_Texto26.Color(clrWhite);
  }

//+------------------------------------------------------------------+
//| REMOVE INDICADORES                                               |
//+------------------------------------------------------------------+

  void RemoveIndicadores()
  {
      long total_windows;

      if(ChartGetInteger(0,CHART_WINDOWS_TOTAL,0,total_windows))
         for(int i=0;i<total_windows;i++)
         {
            long total_indicators=ChartIndicatorsTotal(0,i);
            for(int j=0;j<total_indicators;j++)
               ChartIndicatorDelete(0,i,ChartIndicatorName(0,i,0));
         }
  }

//+------------------------------------------------------------------+
//| FUNÇÃO ONTRADETRANSATION                                         |
//+------------------------------------------------------------------+

 void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
 {
   if(HistoryDealSelect(trans.deal))
   {
     ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY) HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
     string deal_symbol = HistoryDealGetString(trans.deal,DEAL_SYMBOL);
     ulong deal_magic = HistoryDealGetInteger(trans.deal,DEAL_MAGIC);
     string deal_comentario = HistoryDealGetString(trans.deal, DEAL_COMMENT);
     double deal_price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
     double deal_volume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);

     //+------------------------------------------------------------------+
     //| FINANCEIRO                                                       |
     //+------------------------------------------------------------------+

       funcao_verifica_meta_ou_perda_atingida_mes();

     //+------------------------------------------------------------------+
     //| AUMENTOS DE POSIÇÃO PARA TRÁS - PEDRA [PARTE 01]                 |
     //+------------------------------------------------------------------+

       if(ligarAumentosParaTras == Ligado && tipoDeOPeracaoAumento == pedra)
       {
           if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && deal_magic == m_magic)) && deal_symbol == Symbol() && EnumToString(deal_entry) == "DEAL_ENTRY_IN" && (deal_comentario == "C_Robot - " + _Symbol + " - " + string(m_magic) || deal_comentario == "V_Robot - " + _Symbol + " - " + string(m_magic)))
           {
               m_symbol.RefreshRates();

               string valuesDistanciasRE[];
               string valuesVolumeRE[];
               int retDistanciasRE = StringSplit(aumentoParaTras,',',valuesDistanciasRE);
               int retVolumeRE = StringSplit(volumeAumentoParaTras,',',valuesVolumeRE);

               if(retDistanciasRE > 0)
               {
                  for(int i = 0; i < retDistanciasRE; i++)
                  {
                    double distancia = StringToDouble(valuesDistanciasRE[i]);
                    if(points_ == sim) distancia = distancia*_Point;

                    if(deal_comentario == "C_Robot - " + _Symbol + " - " + string(m_magic))
                    {
                      double volume = StringToDouble(valuesVolumeRE[i]);
                      HLinhaCriar("RE"+string(i)+_Symbol+string(m_magic), m_symbol.NormalizePrice(deal_price - distancia), "RE " +string(i+1)+" ["+string(volume)+"]", clrGoldenrod, clrWhite, 130);
                    }else if(deal_comentario == "V_Robot - " + _Symbol + " - " + string(m_magic))
                          {
                             double volume = StringToDouble(valuesVolumeRE[i]);
                             HLinhaCriar("RE"+string(i)+_Symbol+string(m_magic), m_symbol.NormalizePrice(deal_price + distancia), "RE " +string(i+1)+" ["+string(volume)+"]", clrGoldenrod, clrWhite, 130);
                          }
                  }
               }
           }
       } //

     //+------------------------------------------------------------------+
     //| AUMENTOS DE POSIÇÃO PARA TRÁS - PEDRA [PARTE 01]                 |
     //+------------------------------------------------------------------+

       if(ligarAumentosParaTras == Ligado && tipoDeOPeracaoAumento == pedra)
       {
           if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && deal_magic == m_magic)) && deal_symbol == Symbol() && EnumToString(deal_entry) == "DEAL_ENTRY_IN")
           {
               m_symbol.RefreshRates();

               string valuesDistanciasRE[];
               int retDistanciasRE = StringSplit(aumentoParaTras,',',valuesDistanciasRE);

               if(retDistanciasRE > 0)
               {
                  for(int i = 0; i < retDistanciasRE; i++)
                  {
                    if(deal_comentario == "RE_C " + "[" + IntegerToString(i) + "]" + " - " + _Symbol + " - " + string(m_magic))
                    {
                      HLinhaDeletar("RE"+string(i)+_Symbol+string(m_magic));
                      break;
                    }else if(deal_comentario == "RE_V " + "[" + IntegerToString(i) + "]" + " - " + _Symbol + " - " + string(m_magic))
                          {
                             HLinhaDeletar("RE"+string(i)+_Symbol+string(m_magic));
                             break;
                          }
                  }
               }
           }
       } //
   }
 }

//+------------------------------------------------------------------+
//| FUNÇÃO ONTRADE                                                   |
//+------------------------------------------------------------------+

  void OnTrade()
  {
     funcao_verifica_meta_ou_perda_atingida_mes();
  }

//+------------------------------------------------------------------+
//| ON CHART EVENT                                                   |
//+------------------------------------------------------------------+

 void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
     if(id==CHARTEVENT_OBJECT_CLICK)
     {
        if(sparam == "zerar")
        {
          if(ordPendente){ DeletaOrdens(); PosicoesEOrdens(); }
          if(posicaoAberta){ zerar(); PosicoesEOrdens(); }
          Print("Fechando posições abertas e deletando ordens pendentes...");
        }

        ChartRedraw();
     }
  }

//+------------------------------------------------------------------+
//| FUNÇÃO QUE CALCULA O PREÇO MÉDIO                                 |
//+------------------------------------------------------------------+

  double GetCurrentMeanPrice(string symbol, ulong magic)
  {
      ulong  ticket    = 0;
      double volSum    = 0;
      double pvSum     = 0;
      double meanPrice = 0;

      for (int i = 0; i < PositionsTotal(); i++)
         if((ticket = PositionGetTicket(i)) > 0)
         {
            if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && PositionGetInteger(POSITION_MAGIC) == magic)) && PositionGetString(POSITION_SYMBOL) == symbol)
            {
               double price  = PositionGetDouble(POSITION_PRICE_OPEN);
               double volume = PositionGetDouble(POSITION_VOLUME);
               pvSum  += price * volume;
               volSum += volume;
               meanPrice = pvSum / volSum;
            }
         }
      return meanPrice;
  }

//+------------------------------------------------------------------+
//| REENTRADA CONTRA                                                 |
//+------------------------------------------------------------------+

  void ReentradasContra()
  {
     //+------------------------------------------------------------------+
     //| PARTE 01 - COLOCAÇÃO DAS LINHAS E CRIAÇÃO DAS VARIÁVEIS GLOBAIS  |
     //+------------------------------------------------------------------+

         string valuesDistanciasRE[];
         string valuesVolumeRE[];
         string valuesTakeProfitRE[];
         int retDistanciasRE = StringSplit(aumentoParaTras,',',valuesDistanciasRE);
         int retVolumeRE = StringSplit(volumeAumentoParaTras,',',valuesVolumeRE);
         int retTakeProfitRE = StringSplit(stopGainAumentoParaTras,',',valuesTakeProfitRE);

         if(retDistanciasRE > 0 && GlobalVariableGet("RE"+_Symbol+string(m_magic)) == 0 && tipoDeOPeracaoAumento == mercado)
         {
            for(int i = 0; i < retDistanciasRE; i++)
            {
              double distancia = StringToDouble(valuesDistanciasRE[i]);
              if(points_ == sim) distancia = distancia*_Point;

              if(comprado && !vendido && comentario == "C_Robot - " + _Symbol + " - " + string(m_magic))
              {
                double volume = StringToDouble(valuesVolumeRE[i]);
                if(precoDeEntradaRE == 0) precoDeEntradaRE = EntradaCompra();
                HLinhaCriar("RE"+string(i)+_Symbol+string(m_magic), m_symbol.NormalizePrice(precoDeEntradaRE - distancia), "RE " +string(i+1)+" ["+DoubleToString(volume, 2)+"]", clrGoldenrod, clrWhite, 130);
                GlobalVariableSet("RE"+_Symbol+string(m_magic), 1);
              }else if(vendido && !comprado && comentario == "V_Robot - " + _Symbol + " - " + string(m_magic))
                    {
                      double volume = StringToDouble(valuesVolumeRE[i]);
                      if(precoDeEntradaRE == 0) precoDeEntradaRE = EntradaVenda();
                      HLinhaCriar("RE"+string(i)+_Symbol+string(m_magic), m_symbol.NormalizePrice(precoDeEntradaRE + distancia), "RE " +string(i+1)+" ["+string(volume)+"]", clrGoldenrod, clrWhite, 130);
                      GlobalVariableSet("RE"+_Symbol+string(m_magic), 1);
                    }
            }
          }

     //+------------------------------------------------------------------+
     //| PARTE 02 - OPERAÇÃO DE COMPRA [AUMENTOS A MERCADO]               |
     //+------------------------------------------------------------------+

        if(comprado && !vendido && tipoDeOPeracaoAumento == mercado)
        {
         if(retDistanciasRE > 0)
         {
            for(int i = 0; i < retDistanciasRE; i++)
            {
              double distancia = StringToDouble(valuesDistanciasRE[i]);
              if(points_ == sim) distancia = distancia*_Point;
              if(precoDeEntradaRE == 0) precoDeEntradaRE = EntradaCompra();
              if(precoDeEntradaRE == 0) return;

              if(ComentarioCompra("RE_C " + "[" + IntegerToString(i) + "]" + " - " + _Symbol + " - " + string(m_magic)))
                continue;

              if(SymbolInfoDouble(_Symbol, SYMBOL_ASK) <= m_symbol.NormalizePrice(precoDeEntradaRE - distancia))
              {
                  double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  double takeprofit = 0;
                  double take = takeProfitOperacao;
                  double preco_medio = precoDeEntradaOperacao*volumeOperacao;
                  preco_medio += price*StringToDouble(valuesVolumeRE[i]);
                  preco_medio /= volumeOperacao + StringToDouble(valuesVolumeRE[i]);

                  double tp_k = StringToDouble(valuesTakeProfitRE[i]);
                  if(points_ == sim) tp_k = tp_k*_Point;

                  if(StringToDouble(valuesTakeProfitRE[i]) > 0)
                     takeprofit = m_symbol.NormalizePrice(preco_medio + tp_k);
                  else if(StringToDouble(valuesTakeProfitRE[i]) == 0)
                           takeprofit = 0;

                  if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING)
                  {
                     for(int y=0;y<5;y++)
                     {
                        if(m_trade.Buy(NormalizeVolume(StringToDouble(valuesVolumeRE[i])), _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), stopLossOperacao, takeprofit, "RE_C " + "[" + IntegerToString(i) + "]" + " - " + _Symbol + " - " + string(m_magic)))
                        {
                          Print("Robot -> Reentrada de Compra a mercado executada com Sucesso. ");
                          HLinhaDeletar("RE"+string(i)+_Symbol+string(m_magic));
                          Sleep(1000);
                          break;
                        }else Print("Robot -> Não foi possível executar a Reentrada de Compra a mercado. ");
                     }
                  }else if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
                        {
                           for(int y=0;y<5;y++)
                           {
                              if(m_trade.Buy(NormalizeVolume(StringToDouble(valuesVolumeRE[i])), _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), stopLossOperacao, take, "RE_C " + "[" + IntegerToString(i) + "]" + " - " + _Symbol + " - " + string(m_magic)))
                              {
                                  Print("Robot -> Reentrada de Compra a mercado executada com Sucesso. ");
                                  HLinhaDeletar("RE"+string(i)+_Symbol+string(m_magic));
                                  Sleep(1000);
                                  break;
                              }else Print("Robot -> Não foi possível executar a Reentrada de Compra a mercado. ");
                           }
                        }
               }

           }
        }

      }//

     //+------------------------------------------------------------------+
     //| PARTE 03 - OPERAÇÃO DE VENDA [AUMENTOS A MERCADO]                |
     //+------------------------------------------------------------------+

        if(vendido && !comprado && tipoDeOPeracaoAumento == mercado)
        {
         if(retDistanciasRE > 0)
         {
            for(int i = 0; i < retDistanciasRE; i++)
            {
              double distancia = StringToDouble(valuesDistanciasRE[i]);
              if(points_ == sim) distancia = distancia*_Point;
              if(precoDeEntradaRE == 0) precoDeEntradaRE = EntradaVenda();
              if(precoDeEntradaRE == 0) return;

              if(ComentarioVenda("RE_V " + "[" + IntegerToString(i) + "]" + " - " + _Symbol + " - " + string(m_magic)))
                continue;

              if(SymbolInfoDouble(_Symbol, SYMBOL_BID) >= m_symbol.NormalizePrice(precoDeEntradaRE + distancia))
              {
                  double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  double takeprofit = 0;
                  double take = takeProfitOperacao;
                  double preco_medio = precoDeEntradaOperacao*volumeOperacao;
                  preco_medio += price*StringToDouble(valuesVolumeRE[i]);
                  preco_medio /= volumeOperacao + StringToDouble(valuesVolumeRE[i]);

                  double tp_k = StringToDouble(valuesTakeProfitRE[i]);
                  if(points_ == sim) tp_k = tp_k*_Point;

                  if(StringToDouble(valuesTakeProfitRE[i]) > 0)
                     takeprofit = m_symbol.NormalizePrice(preco_medio - tp_k);
                  else if(StringToDouble(valuesTakeProfitRE[i]) == 0)
                           takeprofit = 0;

                  if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING)
                  {
                     for(int y=0;y<5;y++)
                     {
                        if(m_trade.Sell(NormalizeVolume(StringToDouble(valuesVolumeRE[i])), _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), stopLossOperacao, takeprofit, "RE_V " + "[" + IntegerToString(i) + "]" + " - " + _Symbol + " - " + string(m_magic)))
                        {
                          Print("Robot -> Reentrada de Venda a mercado executada com Sucesso. ");
                          HLinhaDeletar("RE"+string(i)+_Symbol+string(m_magic));
                          Sleep(1000);
                          break;
                        }else Print("Robot -> Não foi possível executar a Reentrada de Venda a mercado. ");
                     }
                  }else if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
                        {
                           for(int y=0;y<5;y++)
                           {
                              if(m_trade.Sell(NormalizeVolume(StringToDouble(valuesVolumeRE[i])), _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), stopLossOperacao, take, "RE_V " + "[" + IntegerToString(i) + "]" + " - " + _Symbol + " - " + string(m_magic)))
                              {
                                  Print("Robot -> Reentrada de Venda a mercado executada com Sucesso. ");
                                  HLinhaDeletar("RE"+string(i)+_Symbol+string(m_magic));
                                  Sleep(1000);
                                  break;
                              }else Print("Robot -> Não foi possível executar a Reentrada de Compra a mercado. ");
                           }
                        }
                   }

               }
        }

      }//

     //+------------------------------------------------------------------+
     //| PARTE 04 - OPERAÇÃO DE COMPRA [AUMENTOS NA PEDRA]                |
     //+------------------------------------------------------------------+

        if(comprado && !vendido && GlobalVariableGet("RE"+_Symbol+string(m_magic)) == 0 && tipoDeOPeracaoAumento == pedra)
        {
         if(retDistanciasRE > 0)
         {
            for(int i = 0; i < retDistanciasRE; i++)
            {
              double distancia = StringToDouble(valuesDistanciasRE[i]);
              if(points_ == sim) distancia = distancia*_Point;

              if(precoDeEntradaRE == 0)
                 precoDeEntradaRE = EntradaCompra();

              if(comentario == "C_Robot - " + _Symbol + " - " + string(m_magic) && posicoesAbertas == 1)
              {
                 for(int y=0;y<5;y++)
                 {
                    if(m_trade.BuyLimit(NormalizeVolume(StringToDouble(valuesVolumeRE[i])), m_symbol.NormalizePrice(precoDeEntradaRE - distancia), _Symbol, stopLossOperacao, 0, tipoDeOrdem, 0, "RE_C " + "[" + IntegerToString(i) + "]" + " - " + _Symbol + " - " + string(m_magic)))
                    {
                       Print("Robot -> Ordem de Compra na Pedra [RE] enviada com Sucesso. ");
                       GlobalVariableSet("RE"+_Symbol+string(m_magic), 1);
                       HLinhaCriar("RE"+string(i)+_Symbol+string(m_magic), m_symbol.NormalizePrice(precoDeEntradaRE - distancia), "RE " +string(i+1)+" ["+DoubleToString(StringToDouble(valuesVolumeRE[i]), 2)+"]", clrGoldenrod, clrWhite, 130);
                       Sleep(1000);
                       break;
                    }else Print("Robot -> Não foi possível enviar a Ordem de Compra na Pedra [RE]. ");
                 }
              }

           }
        }

      }//

     //+------------------------------------------------------------------+
     //| PARTE 05 - OPERAÇÃO DE VENDA [AUMENTOS NA PEDRA]                 |
     //+------------------------------------------------------------------+

        if(vendido && !comprado && GlobalVariableGet("RE"+_Symbol+string(m_magic)) == 0 && tipoDeOPeracaoAumento == pedra)
        {
         if(retDistanciasRE > 0)
         {
            for(int i = 0; i < retDistanciasRE; i++)
            {
              double distancia = StringToDouble(valuesDistanciasRE[i]);
              if(points_ == sim) distancia = distancia*_Point;

              if(precoDeEntradaRE == 0)
                 precoDeEntradaRE = EntradaVenda();

              if(comentario == "V_Robot - " + _Symbol + " - " + string(m_magic) && posicoesAbertas == 1)
              {
                 for(int y=0;y<5;y++)
                 {
                    if(m_trade.SellLimit(NormalizeVolume(StringToDouble(valuesVolumeRE[i])), m_symbol.NormalizePrice(precoDeEntradaRE + distancia), _Symbol, stopLossOperacao, 0, tipoDeOrdem, 0, "RE_V " + "[" + IntegerToString(i) + "]" + " - " + _Symbol + " - " + string(m_magic)))
                    {
                       Print("Robot -> Ordem de Venda na Pedra [RE] enviada com Sucesso. ");
                       GlobalVariableSet("RE"+_Symbol+string(m_magic), 1);
                       HLinhaCriar("RE"+string(i)+_Symbol+string(m_magic), m_symbol.NormalizePrice(precoDeEntradaRE + distancia), "RE " +string(i+1)+" ["+DoubleToString(StringToDouble(valuesVolumeRE[i]), 2)+"]", clrGoldenrod, clrWhite, 130);
                       Sleep(1000);
                       break;
                    }else Print("Robot -> Não foi possível enviar a Ordem de Venda na Pedra [RE]. ");
                 }
              }

           }
        }

      }//

      //+------------------------------------------------------------------+
      //| PARTE 06 - AJUSTE DO TP DE COMPRA                                |
      //+------------------------------------------------------------------+

         if(comprado && !vendido)
         {
            if(retDistanciasRE > 0)
            {
               for(int i = 0; i < retDistanciasRE; i++)
               {
                  if(tipoDeOPeracaoAumento == pedra || AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
                  {
                     precoMedio = GetCurrentMeanPrice(_Symbol, m_magic);
                     double takeprofit = 0;

                     double tp_k = StringToDouble(valuesTakeProfitRE[i]);
                     if(points_ == sim) tp_k = tp_k*_Point;

                    if(StringToDouble(valuesTakeProfitRE[i]) > 0)
                       takeprofit = m_symbol.NormalizePrice(precoMedio + tp_k);
                    else if(StringToDouble(valuesTakeProfitRE[i]) == 0)
                            takeprofit = 0;

                     if(comentario == "RE_C " + "[" + IntegerToString(i) + "]" + " - " + _Symbol + " - " + string(m_magic))
                     {
                        if(takeprofit != takeProfitOperacao)
                        {
                           for(int j=PositionsTotal()-1; j>=0; j--)
                           {
                             ulong posTicket = PositionGetTicket(j);

                             if(PositionSelectByTicket(posTicket))
                             {
                                string simbolo = PositionGetString(POSITION_SYMBOL);
                                ulong magic = PositionGetInteger(POSITION_MAGIC);
                                double tp = PositionGetDouble(POSITION_TP);

                                if(posTicket > 0 && magic == m_magic && simbolo == _Symbol && tp != takeprofit)
                                {
                                   if(m_trade.PositionModify(posTicket, stopLossOperacao, takeprofit))
                                     Print("Robot -> Posição de REE de Compra Modificada com Sucesso. ");
                                   else Print("Robot -> Não foi possível modificar a REE de Compra. ");
                                }
                             }
                           }
                        }
                     }
                   }
                }
              }
            }

      //+------------------------------------------------------------------+
      //| PARTE 07 - AJUSTE DO TP DE VENDA                                 |
      //+------------------------------------------------------------------+

         if(vendido && !comprado)
         {
            if(retDistanciasRE > 0)
            {
               for(int i = 0; i < retDistanciasRE; i++)
               {
                  if(tipoDeOPeracaoAumento == pedra || AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
                  {
                     precoMedio = GetCurrentMeanPrice(_Symbol, m_magic);
                     double takeprofit = 0;

                     double tp_k = StringToDouble(valuesTakeProfitRE[i]);
                     if(points_ == sim) tp_k = tp_k*_Point;

                     if(StringToDouble(valuesTakeProfitRE[i]) > 0)
                        takeprofit = m_symbol.NormalizePrice(precoMedio - tp_k);
                     else if(StringToDouble(valuesTakeProfitRE[i]) == 0)
                              takeprofit = 0;

                     if(comentario == "RE_V " + "[" + IntegerToString(i) + "]" + " - " + _Symbol + " - " + string(m_magic))
                     {
                        if(takeprofit != takeProfitOperacao)
                        {
                           for(int j=PositionsTotal()-1; j>=0; j--)
                           {
                             ulong posTicket = PositionGetTicket(j);

                             if(PositionSelectByTicket(posTicket))
                             {
                                string simbolo = PositionGetString(POSITION_SYMBOL);
                                ulong magic = PositionGetInteger(POSITION_MAGIC);
                                double tp = PositionGetDouble(POSITION_TP);

                                if(posTicket > 0 && magic == m_magic && simbolo == _Symbol && tp != takeprofit)
                                {
                                   if(m_trade.PositionModify(posTicket, stopLossOperacao, takeprofit))
                                     Print("Robot -> Posição de REE de Venda Modificada com Sucesso. ");
                                   else Print("Robot -> Não foi possível modificar a REE de Venda. ");
                                }
                             }
                           }
                        }
                     }
                   }
                }
              }
            }
    }

//+------------------------------------------------------------------+
//| RETORNA O PREÇO DA ENTRADA DA OPERAÇÃO                           |
//+------------------------------------------------------------------+

  double EntradaCompra()
  {
      double preco = 0.0;

      if(escolheHabilitarRelogio == Desligado)
        HistorySelect(data_e_hora_ultima_entrada,TimeCurrent());

      if(escolheHabilitarRelogio == Ligado)
        HistorySelect(StringToTime(hoje+" 00:00"),TimeCurrent());

      if(HistoryDealsTotal()==0)
         return false;

      for(int i=HistoryDealsTotal()-1; i>=0; i--)
      {
         ulong ticket = HistoryDealGetTicket(i);
         long Entry  = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         ulong magic  = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         string comment = HistoryDealGetString(ticket, DEAL_COMMENT);

         if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)))
         {
            if(ticket > 0 && Entry == DEAL_ENTRY_IN && HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol && comment == "C_Robot - " + _Symbol + " - " + string(m_magic))
            {
               preco = HistoryDealGetDouble(ticket, DEAL_PRICE);
               break;
            }
         }
      }

      return (preco);
  }

//+------------------------------------------------------------------+
//| RETORNA O PREÇO DA ENTRADA DA OPERAÇÃO                           |
//+------------------------------------------------------------------+

  double EntradaVenda()
  {
      double preco = 0.0;

      if(escolheHabilitarRelogio == Desligado)
        HistorySelect(data_e_hora_ultima_entrada,TimeCurrent());

      if(escolheHabilitarRelogio == Ligado)
        HistorySelect(StringToTime(hoje+" 00:00"),TimeCurrent());

      if(HistoryDealsTotal()==0)
         return false;

      for(int i=HistoryDealsTotal()-1; i>=0; i--)
      {
         ulong ticket = HistoryDealGetTicket(i);
         long Entry  = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         ulong magic  = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         string comment = HistoryDealGetString(ticket, DEAL_COMMENT);

         if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)))
         {
            if(ticket > 0 && Entry == DEAL_ENTRY_IN && HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol && comment == "V_Robot - " + _Symbol + " - " + string(m_magic))
            {
               preco = HistoryDealGetDouble(ticket, DEAL_PRICE);
               break;
            }
         }
      }

      return (preco);
  }

//+------------------------------------------------------------------------------+
//| PEGA A DATA DA ÚLTIMA ENTRADA NA OPERAÇÃO                                    |
//+------------------------------------------------------------------------------+

  datetime funcao_data_ultima_entrada_operacao()
  {
      MqlDateTime str1;
      diaAtual = TimeCurrent();
      TimeToStruct(diaAtual,str1);
      int ano = str1.year;

      HistorySelect(StringToTime(IntegerToString(ano-3) + "." + "01" + "." + "01 00:00"), TimeCurrent());

      if(HistoryDealsTotal() == 0)
            return false;

      for(int i=HistoryDealsTotal()-1; i>=0; i--)
      {
         ulong ticket = HistoryDealGetTicket(i);
         long Entry  = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         ulong magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         string comment = HistoryDealGetString(ticket, DEAL_COMMENT);

         if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && Entry == DEAL_ENTRY_IN && ticket > 0 && HistoryDealGetString(ticket,DEAL_SYMBOL) == _Symbol)
           if(comment == "C_Robot - " + _Symbol + " - " + string(m_magic) || comment == "V_Robot - " + _Symbol + " - " + string(m_magic))
              return (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      }

      return 0;
  }

//+------------------------------------------------------------------+
//| COMENTÁRIO DE COMPRA DA ORDEM                                    |
//+------------------------------------------------------------------+

  bool ComentarioCompra(string coment)
  {
      if(escolheHabilitarRelogio == Desligado)
        HistorySelect(data_e_hora_ultima_entrada,TimeCurrent());

      if(escolheHabilitarRelogio == Ligado)
        HistorySelect(StringToTime(hoje+" 00:00"),TimeCurrent());

      if(HistoryDealsTotal() == 0)
         return false;

      for(int i=HistoryDealsTotal()-1; i>=0; i--)
      {
         ulong ticket = HistoryDealGetTicket(i);
         long Entry  = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         ulong magic  = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         string simbolo = HistoryDealGetString(ticket, DEAL_SYMBOL);

         if(ticket > 0 && ((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && simbolo == _Symbol)
         {
            if(HistoryDealGetString(ticket, DEAL_COMMENT) == coment)
            {
               return true;
               break;
            }

            if(Entry == DEAL_ENTRY_IN && HistoryDealGetString(ticket, DEAL_COMMENT) == "C_Robot - " + _Symbol + " - " + string(m_magic))
               break;
         }
      }

      return(false);
  }

//+------------------------------------------------------------------+
//| COMENTÁRIO DE VENDA DA ORDEM                                     |
//+------------------------------------------------------------------+

  bool ComentarioVenda(string coment)
  {
      if(escolheHabilitarRelogio == Desligado)
        HistorySelect(data_e_hora_ultima_entrada,TimeCurrent());

      if(escolheHabilitarRelogio == Ligado)
        HistorySelect(StringToTime(hoje+" 00:00"),TimeCurrent());

      if(HistoryDealsTotal() == 0)
         return false;

      for(int i=HistoryDealsTotal()-1; i>=0; i--)
      {
         ulong ticket = HistoryDealGetTicket(i);
         long Entry  = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         ulong magic  = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         string simbolo = HistoryDealGetString(ticket, DEAL_SYMBOL);

         if(ticket > 0 && ((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && simbolo == _Symbol)
         {
            if(HistoryDealGetString(ticket, DEAL_COMMENT) == coment)
            {
               return true;
               break;
            }

            if(Entry == DEAL_ENTRY_IN && HistoryDealGetString(ticket, DEAL_COMMENT) == "V_Robot - " + _Symbol + " - " + string(m_magic))
               break;
         }
      }

      return(false);
  }

//+------------------------------------------------------------------+
//| SAÍDAS PARCIAIS                                                  |
//+------------------------------------------------------------------+

  void SaidasParciais()
  {
     //+------------------------------------------------------------------+
     //| PARTE 01                                                         |
     //+------------------------------------------------------------------+

         string valuesDistanciasSP[];
         string valuesVolumeSP[];
         int retDistanciasSP = StringSplit(pontosRealizacao,',',valuesDistanciasSP);
         int retVolumeSP = StringSplit(volumeDaParcial,',',valuesVolumeSP);

         if(retDistanciasSP > 0 && !criarLinhasSP)
         {
            for(int i = 0; i < retDistanciasSP; i++)
            {
              double distancia = StringToDouble(valuesDistanciasSP[i]);
              if(points_ == sim) distancia = distancia*_Point;

              if(comprado && !vendido)
              {
                double volume = StringToDouble(valuesVolumeSP[i]);
                HLinhaCriar("SP"+string(i)+_Symbol+string(m_magic), m_symbol.NormalizePrice(precoMedio + distancia), "SP " +string(i+1)+" ["+string(volume)+"]", clrGreen, clrWhite, 130);

                if(!GlobalVariableCheck("SP"+string(i)+_Symbol+string(m_magic)))
                  GlobalVariableSet("SP"+string(i)+_Symbol+string(m_magic), m_symbol.NormalizePrice(precoMedio + distancia));
                criarLinhasSP = true;
              }else if(vendido && !comprado)
                    {
                       double volume = StringToDouble(valuesVolumeSP[i]);
                       HLinhaCriar("SP"+string(i)+_Symbol+string(m_magic), m_symbol.NormalizePrice(precoMedio - distancia), "SP " +string(i+1)+" ["+string(volume)+"]", clrGreen, clrWhite, 130);

                       if(!GlobalVariableCheck("SP"+string(i)+_Symbol+string(m_magic)))
                         GlobalVariableSet("SP"+string(i)+_Symbol+string(m_magic), m_symbol.NormalizePrice(precoMedio - distancia));
                       criarLinhasSP = true;
                    }
            }
         }

     //+------------------------------------------------------------------+
     //| PARTE 02                                                         |
     //+------------------------------------------------------------------+

        if(comprado && !vendido)
        {
         if(retDistanciasSP > 0)
         {
            for(int i = 0; i < retDistanciasSP; i++)
            {
              double distancia = StringToDouble(valuesDistanciasSP[i]);
              if(points_ == sim) distancia = distancia*_Point;

              if(GlobalVariableGet("SP"+string(i)+_Symbol+string(m_magic)) == 0)
                continue;

              if(SymbolInfoDouble(_Symbol, SYMBOL_ASK) >= m_symbol.NormalizePrice(precoMedio + distancia))
              {
               double volumeParcial = StringToDouble(valuesVolumeSP[i]);

                if(volumeDaPosicaoAberta < volumeParcial && volumeDaPosicaoAberta > 0)
                  volumeParcial = volumeDaPosicaoAberta;

                 if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING)
                 {
                     for(int y=0;y<5;y++)
                     {
                        if(m_trade.Sell(NormalizeVolume(volumeParcial), _Symbol, m_symbol.Bid(), 0, 0, "RP_V " + "[" + IntegerToString(i+1) + "]" + " - " + _Symbol + " - " + string(m_magic)))
                        {
                           Print("Robot -> Realização Parcial (" + IntegerToString(i+1) + ") - sem falha. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                           GlobalVariableSet("SP"+string(i)+_Symbol+string(m_magic), 0);
                           HLinhaDeletar("SP"+string(i)+_Symbol+string(m_magic));
                           Sleep(1000);
                           break;
                        }else Print("Robot -> Realização Parcial (" + IntegerToString(i+1) + ") - com falha. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                     }
                 }else if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
                       {
                          double volume = StringToDouble(valuesVolumeSP[i]);

                          for(int j=PositionsTotal()-1; j>=0; j--)
                          {
                             ulong ticket = PositionGetTicket(j);

                             if(PositionSelectByTicket(ticket))
                             {
                                string simbolo = PositionGetString(POSITION_SYMBOL);
                                ulong magic = PositionGetInteger(POSITION_MAGIC);
                                double volumeOp = PositionGetDouble(POSITION_VOLUME);

                                if(simbolo == _Symbol && magic == m_magic)
                                {
                                  if(volumeOp <= volume && volume > 0)
                                  {
                                     if(m_trade.PositionClose(ticket, 0))
                                     {
                                       Print("Robot -> Realização Parcial (" + IntegerToString(i+1) + ") - sem falha. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                                       GlobalVariableSet("SP"+string(i)+_Symbol+string(m_magic), 0);
                                       HLinhaDeletar("SP"+string(i)+_Symbol+string(m_magic));
                                       volume = volume - volumeOp;
                                     }else Print("Robot -> Realização Parcial (" + IntegerToString(i+1) + ") - com falha. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                                  }else if(volumeOp > volume && volume > 0)
                                        {
                                           if(m_trade.PositionClosePartial(ticket, NormalizeVolume(volume), 0))
                                           {
                                              Print("Robot -> Realização Parcial (" + IntegerToString(i+1) + ") - sem falha. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                                              GlobalVariableSet("SP"+string(i)+_Symbol+string(m_magic), 0);
                                              HLinhaDeletar("SP"+string(i)+_Symbol+string(m_magic));
                                              volume = volume - volumeOp;
                                           }else Print("Robot -> Realização Parcial (" + IntegerToString(i+1) + ") - com falha. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                                        }
                                }

                             }
                          }

                       }

              }
           }
        }

      }//

     //+------------------------------------------------------------------+
     //| PARTE 03                                                         |
     //+------------------------------------------------------------------+

        if(vendido && !comprado)
        {
         if(retDistanciasSP > 0)
         {
            for(int i = 0; i < retDistanciasSP; i++)
            {
              double distancia = StringToDouble(valuesDistanciasSP[i]);
              if(points_ == sim) distancia = distancia*_Point;

              if(GlobalVariableGet("SP"+string(i)+_Symbol+string(m_magic)) == 0)
                continue;

              if(SymbolInfoDouble(_Symbol, SYMBOL_BID) <= m_symbol.NormalizePrice(precoMedio - distancia))
              {
                double volumeParcial = StringToDouble(valuesVolumeSP[i]);

                if(volumeDaPosicaoAberta < volumeParcial && volumeDaPosicaoAberta > 0)
                  volumeParcial = volumeDaPosicaoAberta;

                 if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING)
                 {
                     for(int y=0;y<5;y++)
                     {
                        if(m_trade.Buy(NormalizeVolume(volumeParcial), _Symbol, m_symbol.Ask(), 0, 0, "RP_C " + "[" + IntegerToString(i+1) + "]" + " - " + _Symbol + " - " + string(m_magic)))
                        {
                           Print("Robot -> Realização Parcial (" + IntegerToString(i+1) + ") - sem falha. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                           GlobalVariableSet("SP"+string(i)+_Symbol+string(m_magic), 0);
                           HLinhaDeletar("SP"+string(i)+_Symbol+string(m_magic));
                           Sleep(1000);
                           break;
                        }else Print("Robot -> Realização Parcial (" + IntegerToString(i+1) + ") - com falha. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                     }
                 }else if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
                       {
                          double volume = StringToDouble(valuesVolumeSP[i]);

                          for(int j=PositionsTotal()-1; j>=0; j--)
                          {
                             ulong ticket = PositionGetTicket(j);

                             if(PositionSelectByTicket(ticket))
                             {
                                string simbolo = PositionGetString(POSITION_SYMBOL);
                                ulong magic = PositionGetInteger(POSITION_MAGIC);
                                double volumeOp = PositionGetDouble(POSITION_VOLUME);

                                if(simbolo == _Symbol && magic == m_magic)
                                {
                                  if(volumeOp <= volume && volume > 0)
                                  {
                                     if(m_trade.PositionClose(ticket, 0))
                                     {
                                       Print("Robot -> Realização Parcial (" + IntegerToString(i+1) + ") - sem falha. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                                       GlobalVariableSet("SP"+string(i)+_Symbol+string(m_magic), 0);
                                       HLinhaDeletar("SP"+string(i)+_Symbol+string(m_magic));
                                       volume = volume - volumeOp;
                                     }else Print("Robot -> Realização Parcial (" + IntegerToString(i+1) + ") - com falha. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                                  }else if(volumeOp > volume && volume > 0)
                                        {
                                           if(m_trade.PositionClosePartial(ticket, NormalizeVolume(volume), 0))
                                           {
                                              Print("Robot -> Realização Parcial (" + IntegerToString(i+1) + ") - sem falha. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                                              GlobalVariableSet("SP"+string(i)+_Symbol+string(m_magic), 0);
                                              HLinhaDeletar("SP"+string(i)+_Symbol+string(m_magic));
                                              volume = volume - volumeOp;
                                           }else Print("Robot -> Realização Parcial (" + IntegerToString(i+1) + ") - com falha. ResultRetcode: ",m_trade.ResultRetcode(),", RetcodeDescription: ",m_trade.ResultRetcodeDescription());
                                        }
                                }

                             }
                          }

                       }

              }
           }
        }

      }//
  }

//+------------------------------------------------------------------------------+
//| QUANTIDADE DE TRADES NO DIA                                                  |
//+------------------------------------------------------------------------------+

  int funcao_verifica_quantidade_de_trades_no_dia()
  {
      int contador_trades = 0;

      HistorySelect(StringToTime(hoje+" 00:00"),TimeCurrent());

      int total = HistoryDealsTotal();
      for(int i=0; i<total; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         long Entry  = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
         ulong magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);

         if(((AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING) || (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && magic == m_magic)) && ticket > 0 && Entry == DEAL_ENTRY_IN && HistoryDealGetString(ticket,DEAL_SYMBOL) == _Symbol && (comment == "C_Robot - " + _Symbol + " - " + string(m_magic) || comment == "V_Robot - " + _Symbol + " - " + string(m_magic)))
           contador_trades++;
      }

      return(contador_trades);
  }
