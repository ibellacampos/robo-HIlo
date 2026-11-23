//+------------------------------------------------------------------+
//| EA 12 - SuperTrend + Price Action (ouro M15 / B3)                 |
//|                                                                  |
//| Reconstrucao a partir da LISTA DE PARAMETROS que aparece em um   |
//| video promocional de um EA comercial para XAUUSD (M15). O codigo |
//| original nao e conhecido e o audio nao foi transcrito: os nomes  |
//| e valores dos parametros foram copiados da tela, mas a forma     |
//| como cada um funciona aqui e uma INTERPRETACAO. NAO e o robo do  |
//| video. Pontos interpretados estao marcados com [INTERPRETADO].   |
//|                                                                  |
//| Logica:                                                          |
//|  - Sinal: virada do SuperTrend na vela fechada (periodo, ATR x). |
//|  - Filtro de entrada (0-1) [INTERPRETADO]: na compra a vela de   |
//|    sinal precisa fechar no topo (fech-min)/(max-min) >= filtro;  |
//|    na venda, no fundo.                                           |
//|  - Price Action (opcional) [INTERPRETADO]: as ultimas N velas    |
//|    precisam ter corpo >= X da amplitude, na direcao do sinal, e  |
//|    volume de ticks minimo. Com SuperTrend ligado, confirma; com  |
//|    SuperTrend desligado, gera o sinal sozinho.                   |
//|  - Stop: ATR x mult., fixo em pontos ou Chandelier.              |
//|  - Alvo: fixo (R:R), multiplo (saidas parciais em 1x, 2x e 3x o  |
//|    alvo base) ou so trailing.                                    |
//|  - Break-even, trailing, sessao, spread, sexta/segunda, noticias |
//|    (somente conta real/demo: o calendario nao existe no testador)|
//|  - Gestao: risco % ou lote fixo, fracao de Kelly, ajuste por     |
//|    volatilidade, reducao apos perda, limites diarios e de        |
//|    patrimonio.                                                   |
//+------------------------------------------------------------------+
#property version   "1.00"
#property description "EA12: SuperTrend + Price Action com gestao de risco. Reconstrucao a partir de parametros vistos em video; nao e o robo original."
#include <Trade/Trade.mqh>

enum ENUM_CONTA_ALVO   { CONTA_REAL=0, CONTA_DEMO=1 };
enum ENUM_MODO_LOTE    { LOTE_RISCO_FIXO=0, LOTE_FIXO=1 };
enum ENUM_TIPO_SL      { SL_ATR=0, SL_FIXO=1, SL_CHANDELIER=2 };
enum ENUM_TIPO_TP      { TP_MULTIPLO=0, TP_FIXO=1, TP_TRAILING=2 };

input group "=== 01 CONTROLE ==="
input bool   OperacaoLigada = true;            // Chave geral
input double RiscoPorOperacaoPct = 1.0;        // Risco % por operacao (0,5-2,0%)
input ENUM_CONTA_ALVO ContaAlvo = CONTA_DEMO;  // Conta onde pode operar (alem do testador)
input long   NumeroMagico = 202502;            // Identificador do EA

input group "=== 02 ESTRATEGIA 1: SUPERTREND ==="
input bool   UsarSuperTrend = true;            // Ligar SuperTrend
input int    PeriodoSuperTrend = 10;           // Periodo do ATR do SuperTrend
input double MultiplicadorATR = 3.0;           // Multiplicador do ATR
input double FiltroEntrada = 0.5;              // Filtro de entrada (0-1): posicao do fechamento na vela

input group "=== 03 ESTRATEGIA 2: PRICE ACTION ==="
input bool   UsarPriceAction = true;           // Ligar Price Action
input int    VelasAnalisadas = 3;              // Velas analisadas
input double CorpoMinimo = 0.7;                // Corpo minimo / amplitude (0-1)
input long   VolumeTicksMinimo = 10;           // Volume minimo de ticks por vela

input group "=== 04 GESTAO DE RISCO ==="
input bool   RiscoAdaptativo = true;           // Reduz o risco quando a volatilidade sobe
input double RiscoMaximoDiaPct = 3.0;          // Soma maxima de risco aberto no dia (% do patrimonio)
input double RebaixamentoMaximoDiaPct = 5.0;   // Para no dia se o patrimonio cair X% desde a abertura do dia
input int    PararAposPerdas = 3;              // Para no dia apos X perdas seguidas (0 desliga)
input bool   PararSePatrimonioCair = true;     // Desliga o EA se o patrimonio cair do pico
input double QuedaPatrimonioPct = 10.0;        // Queda do pico que desliga o EA (%)
input bool   MetaDiariaLigada = false;         // Para no dia ao atingir a meta
input double MetaDiariaPct = 5.0;              // Meta diaria (% do patrimonio inicial do dia)

input group "=== 05 TAMANHO DA POSICAO ==="
input ENUM_MODO_LOTE ModoLote = LOTE_RISCO_FIXO; // Risco fixo ou lote fixo
input double LoteFixo = 0.01;                  // Lote quando usar lote fixo
input double LoteMaximo = 0.10;                // Lote maximo
input double LoteMinimo = 0.01;                // Lote minimo
input bool   UsarKelly = false;                // Limitar o risco pela fracao de Kelly do historico
input double FracaoKelly = 0.25;               // Fracao de Kelly usada

input group "=== 06 EXECUCAO ==="
input int    DesvioMaximoPontos = 3;           // Desvio maximo (pontos)
input bool   FechamentoParcial = true;         // Saidas parciais (somente alvo MULTIPLO)
input double ParcialAlvo1Pct = 50.0;           // % fechado no alvo 1
input double ParcialAlvo2Pct = 30.0;           // % fechado no alvo 2
input double ParcialAlvo3Pct = 20.0;           // % fechado no alvo 3 (o resto)

input group "=== 07 STOP E ALVO ==="
input ENUM_TIPO_SL TipoStop = SL_ATR;          // ATR, fixo ou Chandelier
input double MultiplicadorATRStop = 3.0;       // ATR x para o stop (e Chandelier)
input int    StopFixoPontos = 1500;            // Stop fixo em pontos
input ENUM_TIPO_TP TipoAlvo = TP_MULTIPLO;     // Multiplo, fixo ou trailing
input double RiscoRetornoBase = 1.5;           // Alvo base = risco x este valor
input bool   UsarTrailing = true;              // Trailing stop
input int    TrailingInicioPontos = 100;       // Ativa o trailing apos X pontos de lucro
input int    TrailingDistanciaPontos = 6000;   // Distancia do trailing (pontos)

input group "=== 08 BREAK-EVEN ==="
input bool   UsarBreakEven = true;             // Mover o stop para a entrada
input double BreakEvenAposPontos = 200.0;      // Apos X pontos de lucro
input int    BreakEvenFolgaPontos = 5;         // Pontos alem da entrada

input group "=== 09 SESSAO E NOTICIAS ==="
input bool   FiltrarSessao = true;             // Filtrar por horario (servidor)
input string HoraInicio = "00:00";             // Inicio (HH:MM)
input string HoraFim = "23:00";                // Fim (HH:MM)
input string HoraZeragem = "0";                // Zera posicao (HH:MM); 0 desliga (use na B3)
input bool   EvitarNoticias = true;            // Evitar noticias de alto impacto (so fora do testador)
input int    MinutosNoticia = 30;              // Minutos antes/depois da noticia
input string MoedasNoticias = "USD";           // Moedas do calendario (ex.: USD ou BRL)

input group "=== 10 FILTROS ==="
input int    SpreadMaximoPontos = 200;         // Spread maximo (pontos)
input int    PeriodoATRVolatilidade = 7;       // ATR para stop e volatilidade
input bool   ReduzirSextaTarde = true;         // Sexta apos 12:00: risco pela metade; apos 18:00 sem entradas
input bool   CuidadoAberturaSegunda = true;    // Segunda: sem entradas nas 2 primeiras horas

input group "=== 11 RECUPERACAO ==="
input bool   RecuperacaoAutomatica = true;     // Reduz o risco apos uma perda ate o proximo ganho
input double ReducaoRiscoRecuperacaoPct = 50.0;// Reducao do risco em recuperacao (%)
input bool   OperarEmRecuperacao = true;       // Se false, para no dia apos uma perda

input group "=== 12 RELATORIOS E AVISOS ==="
input bool   AvisoEmail = false;               // E-mail (configure em Ferramentas > Opcoes)
input bool   AvisoPush = false;                // Push no celular (configure o MetaQuotes ID)
input bool   RelatorioDiario = true;           // Resumo do dia no Diario
input bool   GravarOperacoesArquivo = true;    // CSV em MQL5/Files
input string TelegramToken = "";               // Token do bot (vazio = desligado)
input string TelegramChatId = "";              // Chat ID
input bool   AvisoTelegram = false;            // Exige liberar https://api.telegram.org em WebRequest

input group "=== 13 VISUAL ==="
input bool   ExibirPainel = true;              // Painel no grafico
input bool   DesenharSuperTrend = true;        // Desenha a linha do SuperTrend
input int    PainelX = 10;                     // Posicao horizontal
input int    PainelY = 20;                     // Posicao vertical

CTrade negociador;
int hATRst=INVALID_HANDLE, hATRvol=INVALID_HANDLE;
datetime ultimaBarra=0;
string prefixo, estado="Iniciando";
bool visual=false;
int minInicio=-1, minFim=-1, minZeragem=-1;

// Estado diario / geral.
datetime diaAtual=0;
double patrimonioInicioDia=0, picoPatrimonio=0;
double riscoAbertoHoje=0;
bool desligado=false;
datetime diaParado=0;
string motivoParada="";

// Estatisticas do historico do EA.
bool historicoSujo=true;
double resultadoDia=0, resultadoTotal=0;
int perdasSeguidasDia=0, ganhosTotal=0, perdasTotal=0, operacoesDia=0;
double mediaGanho=0, mediaPerda=0;
bool emRecuperacao=false;

// SuperTrend (ultima vela fechada).
int tendenciaST=0; double linhaST=0;

//+------------------------------------------------------------------+
int ConverterHorario(string t)
{
   StringTrimLeft(t); StringTrimRight(t);
   if(t=="" || t=="0") return -1;
   string p[];
   if(StringSplit(t,StringGetCharacter(":",0),p)!=2) return -2;
   int h=(int)StringToInteger(p[0]), m=(int)StringToInteger(p[1]);
   if(h<0 || h>23 || m<0 || m>59) return -2;
   return h*60+m;
}
int MinutoAtual() { MqlDateTime d; TimeToStruct(TimeCurrent(),d); return d.hour*60+d.min; }
datetime InicioDia(const datetime t) { MqlDateTime d; TimeToStruct(t,d); d.hour=0; d.min=0; d.sec=0; return StructToTime(d); }

bool AmbientePermitido()
{
   if(!OperacaoLigada) return false;
   if(MQLInfoInteger(MQL_TESTER)) return true;
   bool real=((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL);
   return (ContaAlvo==CONTA_REAL)==real;
}

double PrecoAjustado(const double p)
{
   double passo=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(passo<=0) passo=_Point;
   return NormalizeDouble(MathRound(p/passo)*passo,_Digits);
}

void Avisar(const string msg)
{
   Print(msg);
   if(MQLInfoInteger(MQL_TESTER)) return;
   if(AvisoPush) SendNotification(msg);
   if(AvisoEmail) SendMail("EA12 "+_Symbol,msg);
   if(AvisoTelegram && TelegramToken!="" && TelegramChatId!="")
   {
      string url="https://api.telegram.org/bot"+TelegramToken+"/sendMessage";
      string corpo="chat_id="+TelegramChatId+"&text="+msg;
      char dados[], resposta[]; string cabecalhos;
      StringToCharArray(corpo,dados,0,StringLen(corpo),CP_UTF8);
      if(WebRequest("POST",url,"Content-Type: application/x-www-form-urlencoded\r\n",5000,dados,resposta,cabecalhos)<0)
         Print("Telegram: libere https://api.telegram.org em Ferramentas > Opcoes > Expert Advisors (erro ",GetLastError(),")");
   }
}

void GravarCSV(const string linha)
{
   if(!GravarOperacoesArquivo) return;
   int f=FileOpen("EA12_"+_Symbol+"_operacoes.csv",FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,';');
   if(f==INVALID_HANDLE) return;
   FileSeek(f,0,SEEK_END);
   FileWriteString(f,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+";"+linha+"\r\n");
   FileClose(f);
}

//+------------------------------------------------------------------+
// Posicao do EA (uma por vez).
bool SelecionarPosicao(ulong &ticket)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk>0 && PositionSelectByTicket(tk) && PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==NumeroMagico)
      { ticket=tk; return true; }
   }
   ticket=0; return false;
}

bool ExistePosicaoNoAtivo()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk>0 && PositionSelectByTicket(tk) && PositionGetString(POSITION_SYMBOL)==_Symbol) return true;
   }
   return false;
}

// Dados guardados por posicao (risco inicial e estagio das parciais).
string ChaveGV(const ulong id, const string campo) { return prefixo+IntegerToString((long)id)+"_"+campo; }

//+------------------------------------------------------------------+
void AtualizarHistorico()
{
   if(!historicoSujo) return;
   datetime hoje=InicioDia(TimeCurrent());
   resultadoDia=resultadoTotal=0; perdasSeguidasDia=ganhosTotal=perdasTotal=operacoesDia=0;
   double somaG=0, somaP=0; int ultimoSinal=0;
   if(HistorySelect(0,TimeCurrent()+86400))
   {
      // Agrupa por posicao: resultado da posicao = soma das saidas.
      long ids[]; double res[]; datetime fim[];
      for(int i=0;i<HistoryDealsTotal();i++)
      {
         ulong d=HistoryDealGetTicket(i);
         if(d==0 || HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol || HistoryDealGetInteger(d,DEAL_MAGIC)!=NumeroMagico) continue;
         long tp=HistoryDealGetInteger(d,DEAL_TYPE);
         if(tp!=DEAL_TYPE_BUY && tp!=DEAL_TYPE_SELL) continue;
         double r=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_FEE);
         datetime t=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
         resultadoTotal+=r; if(t>=hoje) resultadoDia+=r;
         long e=HistoryDealGetInteger(d,DEAL_ENTRY);
         if(e==DEAL_ENTRY_IN) { if(t>=hoje) operacoesDia++; continue; }
         long id=HistoryDealGetInteger(d,DEAL_POSITION_ID);
         int k=-1;
         for(int j=ArraySize(ids)-1;j>=0;j--) if(ids[j]==id) { k=j; break; }
         if(k<0) { k=ArraySize(ids); ArrayResize(ids,k+1); ArrayResize(res,k+1); ArrayResize(fim,k+1); ids[k]=id; res[k]=0; }
         res[k]+=r; fim[k]=t;
      }
      for(int k=0;k<ArraySize(ids);k++)
      {
         // Ignora a posicao ainda aberta (com parciais ja realizadas).
         if(PositionSelectByTicket((ulong)ids[k])) continue;
         if(res[k]>0) { ganhosTotal++; somaG+=res[k]; ultimoSinal=1; } else { perdasTotal++; somaP+=-res[k]; ultimoSinal=-1; }
         if(fim[k]>=hoje) { if(res[k]<0) perdasSeguidasDia++; else perdasSeguidasDia=0; }
      }
   }
   mediaGanho=(ganhosTotal>0?somaG/ganhosTotal:0); mediaPerda=(perdasTotal>0?somaP/perdasTotal:0);
   emRecuperacao=(RecuperacaoAutomatica && ultimoSinal<0);
   historicoSujo=false;
}

//+------------------------------------------------------------------+
// SuperTrend sobre velas fechadas. Preenche tendencia/linha em ordem cronologica.
bool CalcularSuperTrend(const int n, int &tend[], double &linha[], datetime &tempos[])
{
   MqlRates r[]; double atr[];
   if(CopyRates(_Symbol,PERIOD_CURRENT,1,n,r)!=n || CopyBuffer(hATRst,0,1,n,atr)!=n) return false;
   ArrayResize(tend,n); ArrayResize(linha,n); ArrayResize(tempos,n);
   double supF=0, infF=0; int t=1;
   for(int i=0;i<n;i++)
   {
      tempos[i]=r[i].time;
      double hl2=(r[i].high+r[i].low)/2.0;
      double sup=hl2+MultiplicadorATR*atr[i], inf=hl2-MultiplicadorATR*atr[i];
      if(i==0) { supF=sup; infF=inf; t=(r[i].close>=hl2?1:-1); }
      else
      {
         supF=(sup<supF || r[i-1].close>supF)?sup:supF;
         infF=(inf>infF || r[i-1].close<infF)?inf:infF;
         if(t<0 && r[i].close>supF) t=1;
         else if(t>0 && r[i].close<infF) t=-1;
      }
      tend[i]=t; linha[i]=(t>0?infF:supF);
   }
   return true;
}

// Price Action: ultimas N velas fechadas na direcao, com corpo e volume minimos.
bool PriceActionConfirma(const int lado)
{
   MqlRates r[];
   int n=MathMax(1,VelasAnalisadas);
   if(CopyRates(_Symbol,PERIOD_CURRENT,1,n,r)!=n) return false;
   for(int i=0;i<n;i++)
   {
      double amp=r[i].high-r[i].low;
      if(amp<=0) return false;
      double corpo=r[i].close-r[i].open;
      if(lado>0 && corpo<=0) return false;
      if(lado<0 && corpo>=0) return false;
      if(MathAbs(corpo)/amp<CorpoMinimo) return false;
      if(r[i].tick_volume<VolumeTicksMinimo) return false;
   }
   return true;
}

// Posicao do fechamento dentro da vela: 1 = maxima, 0 = minima.
bool FiltroPosicaoFechamento(const int lado)
{
   if(FiltroEntrada<=0) return true;
   MqlRates r[];
   if(CopyRates(_Symbol,PERIOD_CURRENT,1,1,r)!=1) return false;
   double amp=r[0].high-r[0].low; if(amp<=0) return false;
   double pos=(r[0].close-r[0].low)/amp;
   return (lado>0 ? pos>=FiltroEntrada : pos<=1.0-FiltroEntrada);
}

//+------------------------------------------------------------------+
bool NoticiaProxima()
{
   if(!EvitarNoticias || MQLInfoInteger(MQL_TESTER)) return false;
   MqlCalendarValue valores[];
   datetime de=TimeTradeServer()-MinutosNoticia*60, ate=TimeTradeServer()+MinutosNoticia*60;
   string moedas[]; int nm=StringSplit(MoedasNoticias,StringGetCharacter(",",0),moedas);
   for(int m=0;m<nm;m++)
   {
      string moeda=moedas[m]; StringTrimLeft(moeda); StringTrimRight(moeda);
      if(CalendarValueHistory(valores,de,ate,NULL,moeda)<=0) continue;
      for(int i=0;i<ArraySize(valores);i++)
      {
         MqlCalendarEvent ev;
         if(CalendarEventById(valores[i].event_id,ev) && ev.importance==CALENDAR_IMPORTANCE_HIGH)
         { estado="Noticia: "+ev.name; return true; }
      }
   }
   return false;
}

bool HorarioPermitido(double &fatorRisco)
{
   fatorRisco=1.0;
   MqlDateTime d; TimeToStruct(TimeCurrent(),d);
   if(FiltrarSessao)
   {
      int agora=d.hour*60+d.min, ini=(minInicio<0?0:minInicio), fim=(minFim<0?24*60:minFim);
      bool dentro=(ini<=fim ? agora>=ini && agora<fim : agora>=ini || agora<fim);
      if(!dentro) { estado="Fora da sessao"; return false; }
   }
   if(ReduzirSextaTarde && d.day_of_week==5)
   {
      if(d.hour>=18) { estado="Sexta a noite: sem entradas"; return false; }
      if(d.hour>=12) fatorRisco*=0.5;
   }
   if(CuidadoAberturaSegunda && d.day_of_week==1 && d.hour<2) { estado="Abertura de segunda: aguardando"; return false; }
   return true;
}

//+------------------------------------------------------------------+
double NormalizarLote(double v)
{
   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), vmax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX), passo=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(passo<=0) passo=vmin;
   v=MathMin(v,MathMin(LoteMaximo,vmax));
   v=MathFloor(v/passo+1e-9)*passo;
   if(v<MathMax(LoteMinimo,vmin)) return 0.0;
   return NormalizeDouble(v,8);
}

// Fator de volatilidade: ATR atual vs media das ultimas 50 velas (nunca aumenta o risco).
double FatorVolatilidade()
{
   if(!RiscoAdaptativo) return 1.0;
   double a[]; if(CopyBuffer(hATRvol,0,1,50,a)!=50) return 1.0;
   double soma=0; for(int i=0;i<50;i++) soma+=a[i];
   double media=soma/50.0, atual=a[49];
   if(atual<=0) return 1.0;
   return MathMax(0.25,MathMin(1.0,media/atual));
}

// Kelly: f = W - (1-W)/R, com W = taxa de acerto e R = ganho medio / perda media.
double LimiteKellyPct()
{
   if(!UsarKelly) return 100.0;
   int n=ganhosTotal+perdasTotal;
   if(n<20 || mediaPerda<=0) return 100.0;   // pouco historico: nao limita
   double W=(double)ganhosTotal/n, R=mediaGanho/mediaPerda;
   double f=W-(1.0-W)/R;
   return MathMax(0.0,f*FracaoKelly*100.0);
}

double DistanciaStop(const int lado, const double entrada)
{
   double atr[]; if(CopyBuffer(hATRvol,0,1,1,atr)!=1 || atr[0]<=0) return 0;
   if(TipoStop==SL_FIXO) return StopFixoPontos*_Point;
   if(TipoStop==SL_ATR) return MultiplicadorATRStop*atr[0];
   // Chandelier: maxima/minima de 22 velas -/+ ATR x mult.
   int ind=(lado>0?iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,22,1):iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,22,1));
   if(ind<0) return MultiplicadorATRStop*atr[0];
   double ext=(lado>0?iHigh(_Symbol,PERIOD_CURRENT,ind):iLow(_Symbol,PERIOD_CURRENT,ind));
   double sl=(lado>0?ext-MultiplicadorATRStop*atr[0]:ext+MultiplicadorATRStop*atr[0]);
   double dist=(lado>0?entrada-sl:sl-entrada);
   return (dist>0?dist:MultiplicadorATRStop*atr[0]);
}

bool Entrar(const int lado, const double fatorHorario)
{
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol,tk) || tk.bid<=0 || tk.ask<=0) return false;
   if(SpreadMaximoPontos>0 && (tk.ask-tk.bid)/_Point>SpreadMaximoPontos) { estado="Spread alto"; return false; }
   double entrada=(lado>0?tk.ask:tk.bid);
   double dist=DistanciaStop(lado,entrada);
   if(dist<=0) { estado="ATR indisponivel"; return false; }
   double passo=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(passo<=0) passo=_Point;
   double minStop=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point+passo;
   dist=MathMax(dist,minStop);
   double sl=PrecoAjustado(lado>0?entrada-dist:entrada+dist);
   double tp=0;
   if(TipoAlvo==TP_FIXO) tp=PrecoAjustado(lado>0?entrada+dist*RiscoRetornoBase:entrada-dist*RiscoRetornoBase);
   if(TipoAlvo==TP_MULTIPLO) tp=PrecoAjustado(lado>0?entrada+dist*RiscoRetornoBase*3:entrada-dist*RiscoRetornoBase*3);

   ENUM_ORDER_TYPE tipo=(lado>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double perda1=0;
   if(!OrderCalcProfit(tipo,_Symbol,1.0,entrada,sl,perda1) || perda1>=0) { estado="Erro no calculo do risco"; return false; }
   double patrimonio=AccountInfoDouble(ACCOUNT_EQUITY);

   double riscoPct=RiscoPorOperacaoPct*fatorHorario*FatorVolatilidade();
   if(emRecuperacao) riscoPct*=(1.0-ReducaoRiscoRecuperacaoPct/100.0);
   riscoPct=MathMin(riscoPct,LimiteKellyPct());
   double lote=(ModoLote==LOTE_FIXO ? LoteFixo : patrimonio*riscoPct/100.0/MathAbs(perda1));
   lote=NormalizarLote(lote);
   if(lote<=0) { estado=StringFormat("Lote abaixo do minimo (risco %.2f%%)",riscoPct); return false; }

   double riscoMoeda=MathAbs(perda1)*lote;
   if(RiscoMaximoDiaPct>0 && patrimonioInicioDia>0 && riscoAbertoHoje+riscoMoeda>patrimonioInicioDia*RiscoMaximoDiaPct/100.0)
   { estado="Risco maximo do dia atingido"; return false; }
   double margem=0;
   if(!OrderCalcMargin(tipo,_Symbol,lote,entrada,margem) || margem>AccountInfoDouble(ACCOUNT_MARGIN_FREE)) { estado="Margem insuficiente"; return false; }

   bool ok=(lado>0?negociador.Buy(lote,_Symbol,0,sl,tp,"EA12 "+(lado>0?"C":"V")):negociador.Sell(lote,_Symbol,0,sl,tp,"EA12 V"));
   uint rc=negociador.ResultRetcode();
   if(!ok || (rc!=TRADE_RETCODE_DONE && rc!=TRADE_RETCODE_DONE_PARTIAL)) { estado="Ordem recusada: "+negociador.ResultRetcodeDescription(); Print(estado); return false; }

   riscoAbertoHoje+=riscoMoeda;
   historicoSujo=true;
   ulong t;
   if(SelecionarPosicao(t))
   {
      long id=PositionGetInteger(POSITION_IDENTIFIER);
      GlobalVariableSet(ChaveGV(id,"R"),dist);
      GlobalVariableSet(ChaveGV(id,"E"),0);
      GlobalVariableSet(ChaveGV(id,"V"),lote);
   }
   string msg=StringFormat("EA12 %s %s: lote %.2f, entrada %s, SL %s, TP %s, risco %.2f (%.2f%%)",lado>0?"COMPRA":"VENDA",_Symbol,lote,
                           DoubleToString(entrada,_Digits),DoubleToString(sl,_Digits),tp>0?DoubleToString(tp,_Digits):"-",riscoMoeda,100*riscoMoeda/patrimonio);
   estado=(lado>0?"Comprado":"Vendido");
   Avisar(msg);
   GravarCSV(StringFormat("%s;%.2f;%s;%s;%s",lado>0?"COMPRA":"VENDA",lote,DoubleToString(entrada,_Digits),DoubleToString(sl,_Digits),DoubleToString(tp,_Digits)));
   return true;
}

//+------------------------------------------------------------------+
// Parciais, break-even e trailing da posicao aberta.
void GerenciarPosicao()
{
   ulong tk;
   if(!SelecionarPosicao(tk)) return;
   bool compra=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   long id=PositionGetInteger(POSITION_IDENTIFIER);
   double entrada=PositionGetDouble(POSITION_PRICE_OPEN), sl=PositionGetDouble(POSITION_SL), tp=PositionGetDouble(POSITION_TP);
   double vol=PositionGetDouble(POSITION_VOLUME);
   MqlTick t; if(!SymbolInfoTick(_Symbol,t)) return;
   double preco=(compra?t.bid:t.ask);
   double lucroPts=(compra?preco-entrada:entrada-preco)/_Point;
   double R=(GlobalVariableCheck(ChaveGV(id,"R"))?GlobalVariableGet(ChaveGV(id,"R")):MathAbs(entrada-sl));
   int estagio=(int)(GlobalVariableCheck(ChaveGV(id,"E"))?GlobalVariableGet(ChaveGV(id,"E")):0);
   double volInicial=(GlobalVariableCheck(ChaveGV(id,"V"))?GlobalVariableGet(ChaveGV(id,"V")):vol);

   // 1) Parciais nos alvos 1x, 2x e 3x do alvo base (o 3o e o TP da ordem).
   if(TipoAlvo==TP_MULTIPLO && FechamentoParcial && R>0 && estagio<2)
   {
      double alvo=R*RiscoRetornoBase*(estagio+1);
      if((compra?preco-entrada:entrada-preco)>=alvo)
      {
         double pct=(estagio==0?ParcialAlvo1Pct:ParcialAlvo2Pct);
         double passo=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP), vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
         double fechar=MathFloor(volInicial*pct/100.0/passo+1e-9)*passo;
         if(fechar>=vmin && vol-fechar>=vmin)
         {
            if(negociador.PositionClosePartial(tk,fechar)) { Avisar(StringFormat("EA12 parcial %d: %.2f fechado",estagio+1,fechar)); historicoSujo=true; }
         }
         GlobalVariableSet(ChaveGV(id,"E"),estagio+1);
         return;
      }
   }

   // 2) Break-even e trailing.
   double novo=sl;
   if(UsarBreakEven && lucroPts>=BreakEvenAposPontos)
   {
      double be=entrada+(compra?1:-1)*BreakEvenFolgaPontos*_Point;
      if(sl==0 || (compra?be>novo:be<novo)) novo=be;
   }
   if(UsarTrailing && lucroPts>=TrailingInicioPontos && TrailingDistanciaPontos>0)
   {
      double tr=preco+(compra?-1:1)*TrailingDistanciaPontos*_Point;
      if(sl==0 || (compra?tr>novo:tr<novo)) novo=tr;
   }
   if(novo==sl) return;
   double passo=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(passo<=0) passo=_Point;
   double minDist=MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*_Point+passo;
   novo=PrecoAjustado(compra?MathMin(novo,t.bid-minDist):MathMax(novo,t.ask+minDist));
   if(compra?novo<=sl+passo*0.5:(sl>0 && novo>=sl-passo*0.5)) return;
   negociador.PositionModify(tk,novo,tp);
}

void FecharPosicao(const string motivo)
{
   ulong tk;
   if(SelecionarPosicao(tk) && negociador.PositionClose(tk)) { historicoSujo=true; Avisar("EA12 posicao fechada: "+motivo); }
}

//+------------------------------------------------------------------+
// Visual.
void Texto(const int linha, const string s, const color cor)
{
   string nome=prefixo+"P"+IntegerToString(linha);
   if(ObjectFind(0,nome)<0)
   {
      ObjectCreate(0,nome,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,nome,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetString(0,nome,OBJPROP_FONT,"Consolas");
      ObjectSetInteger(0,nome,OBJPROP_FONTSIZE,9);
      ObjectSetInteger(0,nome,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nome,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,nome,OBJPROP_XDISTANCE,PainelX+10);
   ObjectSetInteger(0,nome,OBJPROP_YDISTANCE,PainelY+8+linha*17);
   ObjectSetInteger(0,nome,OBJPROP_COLOR,cor);
   ObjectSetString(0,nome,OBJPROP_TEXT,s);
}

void AtualizarPainel()
{
   if(!visual || !ExibirPainel) return;
   string f=prefixo+"BG";
   if(ObjectFind(0,f)<0)
   {
      ObjectCreate(0,f,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,f,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,f,OBJPROP_BGCOLOR,C'26,24,18');
      ObjectSetInteger(0,f,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,f,OBJPROP_COLOR,C'150,120,50');
      ObjectSetInteger(0,f,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,f,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,f,OBJPROP_XDISTANCE,PainelX); ObjectSetInteger(0,f,OBJPROP_YDISTANCE,PainelY);
   ObjectSetInteger(0,f,OBJPROP_XSIZE,330); ObjectSetInteger(0,f,OBJPROP_YSIZE,11*17+12);
   color cinza=C'190,185,170', ouro=C'230,190,90';
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   int n=ganhosTotal+perdasTotal;
   ulong tk; bool pos=SelecionarPosicao(tk);
   double flut=(pos?PositionGetDouble(POSITION_PROFIT):0);
   Texto(0,"EA12 SUPERTREND + PRICE ACTION",ouro);
   Texto(1,_Symbol+" "+StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()),7)+" | "+TimeToString(TimeCurrent(),TIME_SECONDS),cinza);
   Texto(2,"SuperTrend: "+(tendenciaST>0?"ALTA":tendenciaST<0?"BAIXA":"-")+(linhaST>0?" "+DoubleToString(linhaST,_Digits):""),tendenciaST>0?C'80,200,120':tendenciaST<0?C'230,90,90':cinza);
   Texto(3,"Posicao: "+(pos?(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?"COMPRADO ":"VENDIDO ")+DoubleToString(PositionGetDouble(POSITION_VOLUME),2):"nenhuma")+
           (pos?StringFormat(" | %.2f",flut):""),cinza);
   Texto(4,StringFormat("Resultado dia: %.2f | total: %.2f",resultadoDia,resultadoTotal),resultadoDia>=0?C'80,200,120':C'230,90,90');
   Texto(5,StringFormat("Operacoes: %d | acerto: %s",n,n>0?DoubleToString(100.0*ganhosTotal/n,1)+"%":"-"),cinza);
   Texto(6,StringFormat("Perdas seguidas hoje: %d | recuperacao: %s",perdasSeguidasDia,emRecuperacao?"SIM":"nao"),cinza);
   Texto(7,StringFormat("Patrimonio: %.2f | pico: %.2f",eq,picoPatrimonio),cinza);
   Texto(8,StringFormat("Risco aberto hoje: %.2f (max %.1f%%)",riscoAbertoHoje,RiscoMaximoDiaPct),cinza);
   Texto(9,"Estado: "+(desligado?"DESLIGADO - "+motivoParada:estado),desligado?clrTomato:clrKhaki);
   Texto(10,"Reconstrucao propria - nao e o robo do video",C'120,115,100');
   ChartRedraw(0);
}

void DesenharST(const datetime t0,const double v0,const datetime t1,const double v1,const int tend)
{
   if(!visual || !DesenharSuperTrend || v0<=0 || v1<=0) return;
   string nome=prefixo+"ST"+IntegerToString((long)t1);
   if(ObjectFind(0,nome)>=0) return;
   ObjectCreate(0,nome,OBJ_TREND,0,t0,v0,t1,v1);
   ObjectSetInteger(0,nome,OBJPROP_COLOR,tend>0?C'60,180,110':C'220,80,80');
   ObjectSetInteger(0,nome,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,nome,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,nome,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,nome,OBJPROP_HIDDEN,true);
}

void LimparObjetos()
{
   for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--) { string n=ObjectName(0,i,0,-1); if(StringFind(n,prefixo)==0) ObjectDelete(0,n); }
}

//+------------------------------------------------------------------+
int OnInit()
{
   minInicio=ConverterHorario(HoraInicio); minFim=ConverterHorario(HoraFim); minZeragem=ConverterHorario(HoraZeragem);
   if(minInicio==-2 || minFim==-2 || minZeragem==-2) { Print("Horario invalido (use HH:MM ou 0)."); return INIT_PARAMETERS_INCORRECT; }
   if(PeriodoSuperTrend<1 || MultiplicadorATR<=0 || FiltroEntrada<0 || FiltroEntrada>1 || VelasAnalisadas<1 || CorpoMinimo<0 || CorpoMinimo>1 ||
      RiscoPorOperacaoPct<=0 || RiscoPorOperacaoPct>10 || LoteFixo<=0 || LoteMaximo<LoteMinimo || PeriodoATRVolatilidade<1 ||
      MultiplicadorATRStop<=0 || StopFixoPontos<=0 || RiscoRetornoBase<=0 || FracaoKelly<0 || FracaoKelly>1 ||
      ReducaoRiscoRecuperacaoPct<0 || ReducaoRiscoRecuperacaoPct>100 || (!UsarSuperTrend && !UsarPriceAction))
   { Print("Parametros invalidos (ligue pelo menos uma estrategia; filtro e corpo entre 0 e 1)."); return INIT_PARAMETERS_INCORRECT; }

   hATRst=iATR(_Symbol,PERIOD_CURRENT,PeriodoSuperTrend);
   hATRvol=iATR(_Symbol,PERIOD_CURRENT,PeriodoATRVolatilidade);
   if(hATRst==INVALID_HANDLE || hATRvol==INVALID_HANDLE) { Print("Falha ao criar ATR."); return INIT_FAILED; }

   negociador.SetExpertMagicNumber((ulong)NumeroMagico);
   negociador.SetDeviationInPoints((ulong)DesvioMaximoPontos);
   negociador.SetTypeFillingBySymbol(_Symbol);
   negociador.LogLevel(LOG_LEVEL_ERRORS);

   prefixo="EA12_"+IntegerToString(NumeroMagico)+"_";
   visual=(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE));
   ultimaBarra=iTime(_Symbol,PERIOD_CURRENT,0);
   picoPatrimonio=AccountInfoDouble(ACCOUNT_EQUITY);
   patrimonioInicioDia=picoPatrimonio; diaAtual=InicioDia(TimeCurrent());
   if(visual)
   {
      ChartSetInteger(0,CHART_FOREGROUND,false);
      EventSetTimer(1);
      int te[]; double li[]; datetime tm[];
      if(CalcularSuperTrend(300,te,li,tm))
         for(int i=1;i<ArraySize(te);i++) if(te[i]==te[i-1]) DesenharST(tm[i-1],li[i-1],tm[i],li[i],te[i]);
      AtualizarHistorico(); AtualizarPainel();
   }
   if(!MQLInfoInteger(MQL_TESTER) && !AmbientePermitido())
      Print("EA12: esta conta nao corresponde a 'Conta onde pode operar' (grupo 01). O EA nao vai abrir ordens.");
   PrintFormat("EA12 iniciado: %s %s, SuperTrend %d x%.2f, PA %s, risco %.2f%%, SL %s, TP %s",_Symbol,EnumToString((ENUM_TIMEFRAMES)Period()),
               PeriodoSuperTrend,MultiplicadorATR,UsarPriceAction?"ligado":"desligado",RiscoPorOperacaoPct,EnumToString(TipoStop),EnumToString(TipoAlvo));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int motivo)
{
   if(visual) { EventKillTimer(); LimparObjetos(); ChartRedraw(0); }
   IndicatorRelease(hATRst); IndicatorRelease(hATRvol);
}

void OnTimer() { AtualizarHistorico(); AtualizarPainel(); }

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res)
{
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD) historicoSujo=true;
}

double OnTester()
{
   double ops=TesterStatistics(STAT_TRADES), lucro=TesterStatistics(STAT_PROFIT);
   double dd=TesterStatistics(STAT_EQUITY_DD), pf=TesterStatistics(STAT_PROFIT_FACTOR);
   if(ops<30 || lucro<=0) return 0.0;
   if(dd<=0) dd=1.0;
   return (lucro/dd)*MathMin(pf,5.0);
}

//+------------------------------------------------------------------+
void NovoDia()
{
   datetime hoje=InicioDia(TimeCurrent());
   if(hoje==diaAtual) return;
   if(RelatorioDiario)
      Avisar(StringFormat("EA12 resumo de %s: resultado %.2f, perdas seguidas %d, total %.2f",TimeToString(diaAtual,TIME_DATE),resultadoDia,perdasSeguidasDia,resultadoTotal));
   diaAtual=hoje;
   patrimonioInicioDia=AccountInfoDouble(ACCOUNT_EQUITY);
   riscoAbertoHoje=0;
   historicoSujo=true;
}

void OnTick()
{
   NovoDia();
   AtualizarHistorico();
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   picoPatrimonio=MathMax(picoPatrimonio,eq);
   if(!AmbientePermitido()) { estado="Bloqueado (chave geral ou tipo de conta)"; return; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED)) { estado="Algotrading desligado"; return; }

   ulong tk; bool posicionado=SelecionarPosicao(tk);

   // Desligamento por queda do patrimonio.
   if(!desligado && PararSePatrimonioCair && QuedaPatrimonioPct>0 && eq<=picoPatrimonio*(1-QuedaPatrimonioPct/100.0))
   { desligado=true; motivoParada=StringFormat("patrimonio caiu %.1f%% do pico",100*(picoPatrimonio-eq)/picoPatrimonio); Avisar("EA12 DESLIGADO: "+motivoParada); }
   if(desligado) { if(posicionado) FecharPosicao(motivoParada); return; }

   // Zeragem diaria (B3).
   if(minZeragem>=0 && MinutoAtual()>=minZeragem) { if(posicionado) FecharPosicao("horario de zeragem"); estado="Horario de zeragem"; return; }

   GerenciarPosicao();

   // Paradas do dia.
   datetime hoje=InicioDia(TimeCurrent());
   if(diaParado!=hoje)
   {
      string m="";
      if(RebaixamentoMaximoDiaPct>0 && patrimonioInicioDia>0 && eq<=patrimonioInicioDia*(1-RebaixamentoMaximoDiaPct/100.0)) m="rebaixamento do dia";
      else if(PararAposPerdas>0 && perdasSeguidasDia>=PararAposPerdas) m=IntegerToString(perdasSeguidasDia)+" perdas seguidas";
      else if(MetaDiariaLigada && patrimonioInicioDia>0 && eq>=patrimonioInicioDia*(1+MetaDiariaPct/100.0)) m="meta diaria";
      else if(!OperarEmRecuperacao && emRecuperacao && resultadoDia<0) m="perda no dia (recuperacao sem operar)";
      if(m!="") { diaParado=hoje; motivoParada=m; Avisar("EA12 parado ate amanha: "+m); if(posicionado && m!="meta diaria") FecharPosicao(m); }
   }
   if(diaParado==hoje) { estado="Parado hoje: "+motivoParada; return; }

   // Sinal so uma vez por vela nova.
   datetime barra=iTime(_Symbol,PERIOD_CURRENT,0);
   if(barra==0 || barra==ultimaBarra) return;
   int te[]; double li[]; datetime tm[];
   int n=MathMax(PeriodoSuperTrend*10,100);
   if(!CalcularSuperTrend(n,te,li,tm)) { estado="Aguardando dados"; return; }
   ultimaBarra=barra;
   tendenciaST=te[n-1]; linhaST=li[n-1];
   if(te[n-1]==te[n-2]) DesenharST(tm[n-2],li[n-2],tm[n-1],li[n-1],te[n-1]);

   int sinal=0;
   if(UsarSuperTrend)
   {
      if(te[n-1]!=te[n-2]) sinal=te[n-1];
      if(sinal!=0 && !FiltroPosicaoFechamento(sinal)) { estado="Virada filtrada (fechamento fraco)"; sinal=0; }
      if(sinal!=0 && UsarPriceAction && !PriceActionConfirma(sinal)) { estado="Virada sem confirmacao do Price Action"; sinal=0; }
   }
   else
   {
      if(PriceActionConfirma(1)) sinal=1; else if(PriceActionConfirma(-1)) sinal=-1;
   }
   if(sinal==0) return;
   if(posicionado || ExistePosicaoNoAtivo()) { estado="Sinal ignorado: ja posicionado"; return; }
   double fator;
   if(!HorarioPermitido(fator)) return;
   if(NoticiaProxima()) return;
   Entrar(sinal,fator);
}
//+------------------------------------------------------------------+
