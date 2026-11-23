//+------------------------------------------------------------------+
//| EA 10 - Grade Hedge (cestas de compra e venda independentes)      |
//|                                                                  |
//| Reconstrucao a partir dos PARAMETROS VISIVEIS em um video de     |
//| demonstracao (XAUUSD, H1). O audio nao foi transcrito e o codigo |
//| original nao e conhecido: a logica de entrada abaixo e uma       |
//| interpretacao. NAO e o robo do video.                            |
//|                                                                  |
//| Logica:                                                          |
//|  - Mantem ate duas cestas: COMPRAS e VENDAS (conta HEDGING).     |
//|  - Cesta vazia + horario permitido -> abre 1 ordem com "Lote".   |
//|  - Preco anda contra a ultima ordem da cesta "DistanciaGrade"    |
//|    pontos -> abre nova ordem com lote anterior x "Fator".        |
//|  - Lucro da cesta >= "LimiteGanhoCesta" ($) -> fecha a cesta     |
//|    inteira; ela reabre no tick seguinte.                         |
//|  - Limites diarios em $, horario de envio e de encerramento.     |
//|                                                                  |
//| v1.10: suporte a conta NETTING (B3). Nela so existe uma posicao   |
//| por ativo, entao opera UMA cesta (somente compra ou somente      |
//| venda); a grade soma contratos a mesma posicao.                  |
//|                                                                  |
//| RISCO: grade com multiplicacao tem curva suave ate o dia em que  |
//| o preco anda muito numa direcao so. As protecoes do grupo 06     |
//| nao existem no video e vem LIGADAS por padrao.                   |
//+------------------------------------------------------------------+
#property version   "1.10"
#property description "EA10: grade com cestas de compra e venda. Reconstrucao a partir de parametros vistos em video; nao e o robo original."
#include <Trade/Trade.mqh>

enum ENUM_TIPO_TRADES
{
   TRADES_COMPRA = 0,   // Somente compras
   TRADES_VENDA  = 1,   // Somente vendas
   TRADES_AMBOS  = 2    // Compras e vendas (duas cestas)
};

input group "01 - PARAMETROS BASICOS"
input long NumeroMagico = 123;                 // Numero magico
input bool PermitirNoTestador = true;          // Operar no testador
input bool PermitirEmDemo = false;             // Operar em conta demo
input bool PermitirEmContaReal = false;        // Operar em conta real (bloqueado por padrao)
input bool MostrarDiagnosticos = true;         // Mensagens no Diario

input group "02 - LIMITES DIARIOS ($) | 0 desligado"
input double LimiteGanhoDiario = 0.0;          // Fecha tudo e para no dia ao ganhar $X (fechado + aberto)
input double LimitePerdaDiario = 0.0;          // Fecha tudo e para no dia ao perder $X (fechado + aberto)

input group "03 - LIMITES POR CESTA ($) | 0 desligado"
input double LimiteGanhoCesta = 5.0;           // Fecha a cesta ao atingir $X de lucro (obrigatorio > 0)
input double LimitePerdaCesta = 0.0;           // Fecha a cesta ao atingir $X de prejuizo

input group "04 - HORARIOS (HH:MM, horario do servidor) | 0 desligado"
input string InicioEnvioOrdens = "00:01";      // A partir deste horario abre novas cestas
input string TerminoEnvioOrdens = "23:59";     // Depois deste horario nao abre novas cestas
input string HorarioEncerrarTudo = "0";        // Fecha todas as posicoes neste horario

input group "05 - PARAMETROS OPERACIONAIS"
input ENUM_TIPO_TRADES TipoTrades = TRADES_AMBOS; // Lados operados
input double Lote = 0.01;                      // Lote da primeira ordem de cada cesta
input int DistanciaGradePontos = 2000;         // Pontos contra a ultima ordem para abrir outra; 0 = sem grade
input double FatorMultiplicacao = 1.0;         // Lote da nova ordem = lote anterior x fator (1 = sem martingale)

input group "06 - PROTECOES (nao existem no video)"
input int MaximoOrdensPorCesta = 8;            // Limite de ordens em cada cesta; 0 = sem limite (perigoso)
input double LoteMaximo = 0.64;                // Lote maximo de uma ordem; 0 = sem limite
input double StopPatrimonioPct = 30.0;         // Fecha tudo e desliga se patrimonio cair X% do pico; 0 desliga
input int SpreadMaximoPontos = 0;              // Nao abre ordens com spread acima disso; 0 desliga
input int DesvioMaximoPontos = 50;             // Desvio maximo na execucao

input group "07 - PAINEL"
input bool ExibirPainel = true;                // Mostrar painel no grafico / teste visual
input int PainelX = 10;                        // Posicao horizontal
input int PainelY = 20;                        // Posicao vertical

input group "08 - OTIMIZACAO (OnTester)"
input int MinimoOperacoesOtimizacao = 30;      // Abaixo disso o criterio personalizado retorna 0

struct Cesta
{
   int      qtd;
   double   lotes;
   double   lucro;
   double   precoMedio;
   double   precoUltima;
   double   loteUltimo;
};

CTrade negociador;
string prefixo;
bool painelDisponivel=false;
string estado="Iniciando";

int minInicio=-1, minTermino=-1, minEncerrar=-1;

// Historico (recalculado quando ha transacao ou muda o dia).
bool historicoSujo=true;
datetime diaHistorico=0;
double fechadoDia=0.0, fechadoMes=0.0;
int operacoesFechadas=0;

// Drawdown pelo patrimonio.
double picoTotal=0.0, picoDia=0.0, picoMes=0.0;
double ddTotal=0.0, ddDia=0.0, ddMes=0.0;
datetime diaDD=0, mesDD=0;

datetime diaBloqueado=0;
bool desligadoPorPatrimonio=false;
datetime ultimoPainel=0;
bool contaNetting=false;

//+------------------------------------------------------------------+
bool AmbientePermitido()
{
   if(MQLInfoInteger(MQL_TESTER)) return PermitirNoTestador;
   if((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL)
      return PermitirEmContaReal;
   return PermitirEmDemo;
}

// "HH:MM" -> minutos do dia; "0" ou vazio -> -1 (desligado); invalido -> -2.
int ConverterHorario(string texto)
{
   StringTrimLeft(texto); StringTrimRight(texto);
   if(texto=="" || texto=="0") return -1;
   string partes[];
   if(StringSplit(texto,StringGetCharacter(":",0),partes)!=2) return -2;
   int h=(int)StringToInteger(partes[0]);
   int m=(int)StringToInteger(partes[1]);
   if(h<0 || h>23 || m<0 || m>59) return -2;
   return h*60+m;
}

int MinutoAtual()
{
   MqlDateTime d; TimeToStruct(TimeCurrent(),d);
   return d.hour*60+d.min;
}

datetime InicioDia(const datetime t)
{
   MqlDateTime d; TimeToStruct(t,d); d.hour=0; d.min=0; d.sec=0;
   return StructToTime(d);
}

datetime InicioMes(const datetime t)
{
   MqlDateTime d; TimeToStruct(t,d); d.day=1; d.hour=0; d.min=0; d.sec=0;
   return StructToTime(d);
}

// Janela de envio de novas cestas.
bool DentroDoHorarioDeEnvio()
{
   if(minInicio<0 && minTermino<0) return true;
   int agora=MinutoAtual();
   int ini=(minInicio<0?0:minInicio);
   int fim=(minTermino<0?24*60:minTermino);
   if(ini<=fim) return agora>=ini && agora<=fim;
   return agora>=ini || agora<=fim;   // janela que atravessa a meia-noite
}

//+------------------------------------------------------------------+
bool PosicaoDoEA()
{
   return PositionGetString(POSITION_SYMBOL)==_Symbol &&
          PositionGetInteger(POSITION_MAGIC)==NumeroMagico;
}

void LerCesta(const ENUM_POSITION_TYPE tipo, Cesta &c)
{
   c.qtd=0; c.lotes=0; c.lucro=0; c.precoMedio=0; c.precoUltima=0; c.loteUltimo=0;
   long ultimoTempo=-1;
   long idPosicao=0;
   double somaPrecoLote=0.0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket) || !PosicaoDoEA()) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)!=tipo) continue;
      double vol=PositionGetDouble(POSITION_VOLUME);
      double preco=PositionGetDouble(POSITION_PRICE_OPEN);
      c.qtd++;
      c.lotes+=vol;
      c.lucro+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      somaPrecoLote+=preco*vol;
      long tempo=PositionGetInteger(POSITION_TIME_MSC);
      if(tempo>ultimoTempo) { ultimoTempo=tempo; c.precoUltima=preco; c.loteUltimo=vol; }
      if(contaNetting) idPosicao=PositionGetInteger(POSITION_IDENTIFIER);
   }
   if(c.lotes>0) c.precoMedio=somaPrecoLote/c.lotes;

   // NETTING: a posicao unica guarda so o preco medio. Ordens da grade, ultimo
   // preco e ultimo lote vem dos negocios de entrada dessa posicao.
   if(contaNetting && c.qtd>0 && idPosicao>0 && HistorySelectByPosition(idPosicao))
   {
      int entradas=0;
      long ultimo=-1;
      for(int i=0;i<HistoryDealsTotal();i++)
      {
         ulong tk=HistoryDealGetTicket(i);
         if(tk==0) continue;
         long entrada=HistoryDealGetInteger(tk,DEAL_ENTRY);
         if(entrada!=DEAL_ENTRY_IN && entrada!=DEAL_ENTRY_INOUT) continue;
         entradas++;
         long t=HistoryDealGetInteger(tk,DEAL_TIME_MSC);
         if(t>ultimo)
         {
            ultimo=t;
            c.precoUltima=HistoryDealGetDouble(tk,DEAL_PRICE);
            c.loteUltimo=HistoryDealGetDouble(tk,DEAL_VOLUME);
         }
      }
      if(entradas>0) c.qtd=entradas;
   }
}

bool FecharCesta(const ENUM_POSITION_TYPE tipo, const string motivo)
{
   bool tudoOk=true;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket) || !PosicaoDoEA()) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)!=tipo) continue;
      if(!negociador.PositionClose(ticket))
      {
         tudoOk=false;
         PrintFormat("Falha ao fechar %I64u: %s",ticket,negociador.ResultRetcodeDescription());
      }
   }
   historicoSujo=true;
   if(MostrarDiagnosticos)
      PrintFormat("Cesta de %s fechada: %s",tipo==POSITION_TYPE_BUY?"COMPRAS":"VENDAS",motivo);
   return tudoOk;
}

void FecharTudo(const string motivo)
{
   FecharCesta(POSITION_TYPE_BUY,motivo);
   FecharCesta(POSITION_TYPE_SELL,motivo);
}

int TotalPosicoesDoEA()
{
   int q=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket>0 && PositionSelectByTicket(ticket) && PosicaoDoEA()) q++;
   }
   return q;
}

//+------------------------------------------------------------------+
double NormalizarLote(double desejado)
{
   double minimo=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maximo=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double passo=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(minimo<=0 || passo<=0) return 0.0;
   if(LoteMaximo>0.0) desejado=MathMin(desejado,LoteMaximo);
   desejado=MathMin(desejado,maximo);
   double vol=MathFloor(desejado/passo+1e-9)*passo;
   if(vol<minimo) vol=minimo;
   return NormalizeDouble(vol,8);
}

bool SpreadOk()
{
   if(SpreadMaximoPontos<=0) return true;
   long spread=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   if(spread>SpreadMaximoPontos)
   {
      estado=StringFormat("Spread %d > %d",(int)spread,SpreadMaximoPontos);
      return false;
   }
   return true;
}

bool AbrirOrdem(const ENUM_POSITION_TYPE lado, const double loteDesejado, const string comentario)
{
   if(!SpreadOk()) return false;
   double vol=NormalizarLote(loteDesejado);
   if(vol<=0) { estado="Lote invalido"; return false; }
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<=0) return false;
   ENUM_ORDER_TYPE tipo=(lado==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double preco=(lado==POSITION_TYPE_BUY?tick.ask:tick.bid);
   double margem=0.0;
   if(!OrderCalcMargin(tipo,_Symbol,vol,preco,margem) || margem>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   {
      estado="Margem insuficiente";
      return false;
   }
   bool ok=(lado==POSITION_TYPE_BUY ? negociador.Buy(vol,_Symbol,0.0,0.0,0.0,comentario)
                                    : negociador.Sell(vol,_Symbol,0.0,0.0,0.0,comentario));
   uint rc=negociador.ResultRetcode();
   if(!ok || (rc!=TRADE_RETCODE_DONE && rc!=TRADE_RETCODE_DONE_PARTIAL))
   {
      estado="Ordem recusada: "+negociador.ResultRetcodeDescription();
      PrintFormat("ORDEM RECUSADA (%s %.2f): %s",lado==POSITION_TYPE_BUY?"compra":"venda",vol,negociador.ResultRetcodeDescription());
      return false;
   }
   historicoSujo=true;
   return true;
}

//+------------------------------------------------------------------+
void AtualizarHistorico()
{
   datetime hoje=InicioDia(TimeCurrent());
   if(!historicoSujo && hoje==diaHistorico) return;
   datetime mes=InicioMes(TimeCurrent());
   fechadoDia=0.0; fechadoMes=0.0;
   if(HistorySelect(mes,TimeCurrent()+86400))
   {
      int n=HistoryDealsTotal();
      for(int i=0;i<n;i++)
      {
         ulong tk=HistoryDealGetTicket(i);
         if(tk==0) continue;
         if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol) continue;
         if(HistoryDealGetInteger(tk,DEAL_MAGIC)!=NumeroMagico) continue;
         long tipo=HistoryDealGetInteger(tk,DEAL_TYPE);
         if(tipo!=DEAL_TYPE_BUY && tipo!=DEAL_TYPE_SELL) continue;
         double r=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_COMMISSION)
                 +HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_FEE);
         fechadoMes+=r;
         if((datetime)HistoryDealGetInteger(tk,DEAL_TIME)>=hoje) fechadoDia+=r;
      }
   }
   diaHistorico=hoje;
   historicoSujo=false;
}

void AtualizarDrawdown()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   datetime hoje=InicioDia(TimeCurrent());
   datetime mes=InicioMes(TimeCurrent());
   if(hoje!=diaDD) { diaDD=hoje; picoDia=eq; ddDia=0.0; }
   if(mes!=mesDD)  { mesDD=mes;  picoMes=eq; ddMes=0.0; }
   picoTotal=MathMax(picoTotal,eq); picoDia=MathMax(picoDia,eq); picoMes=MathMax(picoMes,eq);
   ddTotal=MathMax(ddTotal,picoTotal-eq);
   ddDia=MathMax(ddDia,picoDia-eq);
   ddMes=MathMax(ddMes,picoMes-eq);
}

//+------------------------------------------------------------------+
// Painel proprio (layout e cores deste EA).
void Rotulo(const int linha, const string texto, const color cor, const int coluna=0)
{
   string nome=prefixo+"L"+IntegerToString(linha)+"_"+IntegerToString(coluna);
   if(ObjectFind(0,nome)<0)
   {
      ObjectCreate(0,nome,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,nome,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetString(0,nome,OBJPROP_FONT,"Consolas");
      ObjectSetInteger(0,nome,OBJPROP_FONTSIZE,9);
      ObjectSetInteger(0,nome,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nome,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,nome,OBJPROP_XDISTANCE,PainelX+10+coluna*170);
   ObjectSetInteger(0,nome,OBJPROP_YDISTANCE,PainelY+8+linha*18);
   ObjectSetInteger(0,nome,OBJPROP_COLOR,cor);
   ObjectSetString(0,nome,OBJPROP_TEXT,texto);
}

string Dinheiro(const double v) { return DoubleToString(v,2)+" "+AccountInfoString(ACCOUNT_CURRENCY); }
color CorValor(const double v) { return v>=0?clrMediumSeaGreen:clrTomato; }

void AtualizarPainel(const Cesta &c, const Cesta &v)
{
   if(!painelDisponivel) return;
   string fundo=prefixo+"FUNDO";
   if(ObjectFind(0,fundo)<0)
   {
      ObjectCreate(0,fundo,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,fundo,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,fundo,OBJPROP_BGCOLOR,C'24,30,38');
      ObjectSetInteger(0,fundo,OBJPROP_BORDER_COLOR,C'70,90,110');
      ObjectSetInteger(0,fundo,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,fundo,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,fundo,OBJPROP_XDISTANCE,PainelX);
   ObjectSetInteger(0,fundo,OBJPROP_YDISTANCE,PainelY);
   ObjectSetInteger(0,fundo,OBJPROP_XSIZE,350);
   ObjectSetInteger(0,fundo,OBJPROP_YSIZE,16*18+16);

   double atual=c.lucro+v.lucro;
   string tipo=(TipoTrades==TRADES_AMBOS?"Compra + Venda":TipoTrades==TRADES_COMPRA?"Compra":"Venda");
   Rotulo(0,"EA10 GRADE HEDGE | "+_Symbol,clrWhite);
   Rotulo(1,"Hora servidor: "+TimeToString(TimeCurrent(),TIME_MINUTES|TIME_SECONDS)+" | "+tipo,clrSilver);
   Rotulo(2,"Resultado atual: "+Dinheiro(atual),CorValor(atual));
   Rotulo(3,"Resultado do dia: "+Dinheiro(fechadoDia+atual),CorValor(fechadoDia+atual));
   Rotulo(4,"Resultado do mes: "+Dinheiro(fechadoMes+atual),CorValor(fechadoMes+atual));
   Rotulo(5,"Drawdown dia/mes/total: "+DoubleToString(ddDia,2)+" / "+DoubleToString(ddMes,2)+" / "+DoubleToString(ddTotal,2),clrSkyBlue);
   Rotulo(6,"COMPRAS: "+IntegerToString(c.qtd)+" ordens, "+DoubleToString(c.lotes,2)+" lotes",clrSilver);
   Rotulo(7,"  Preco medio: "+(c.qtd>0?DoubleToString(c.precoMedio,_Digits):"-")+" | Saldo: "+DoubleToString(c.lucro,2),CorValor(c.lucro));
   Rotulo(8,"VENDAS:  "+IntegerToString(v.qtd)+" ordens, "+DoubleToString(v.lotes,2)+" lotes",clrSilver);
   Rotulo(9,"  Preco medio: "+(v.qtd>0?DoubleToString(v.precoMedio,_Digits):"-")+" | Saldo: "+DoubleToString(v.lucro,2),CorValor(v.lucro));
   Rotulo(10,"Alvo cesta: "+DoubleToString(LimiteGanhoCesta,2)+" | Grade: "+IntegerToString(DistanciaGradePontos)+" pts x"+DoubleToString(FatorMultiplicacao,2),clrSilver);
   Rotulo(11,"Max ordens/cesta: "+(MaximoOrdensPorCesta>0?IntegerToString(MaximoOrdensPorCesta):"sem limite")+" | Lote max: "+(LoteMaximo>0?DoubleToString(LoteMaximo,2):"-"),clrSilver);
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   Rotulo(12,"Saldo: "+DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2)+" | Patrimonio: "+DoubleToString(eq,2),clrWhite);
   Rotulo(13,"Margem livre: "+DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE),2),clrWhite);
   Rotulo(14,"Estado: "+estado,desligadoPorPatrimonio?clrTomato:clrKhaki);
   Rotulo(15,"Reconstrucao propria - nao e o robo do video",C'150,150,150');
   ChartRedraw(0);
}

void LimparPainel()
{
   for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--)
   {
      string nome=ObjectName(0,i,0,-1);
      if(StringFind(nome,prefixo)==0) ObjectDelete(0,nome);
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   minInicio=ConverterHorario(InicioEnvioOrdens);
   minTermino=ConverterHorario(TerminoEnvioOrdens);
   minEncerrar=ConverterHorario(HorarioEncerrarTudo);
   if(minInicio==-2 || minTermino==-2 || minEncerrar==-2)
   {
      Print("Horario invalido. Use HH:MM (ex.: 09:30) ou 0 para desligar.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(NumeroMagico<=0 || Lote<=0 || LimiteGanhoCesta<=0 || LimitePerdaCesta<0 ||
      LimiteGanhoDiario<0 || LimitePerdaDiario<0 || DistanciaGradePontos<0 ||
      FatorMultiplicacao<1.0 || FatorMultiplicacao>10.0 || MaximoOrdensPorCesta<0 || LoteMaximo<0 ||
      StopPatrimonioPct<0 || StopPatrimonioPct>=100 || SpreadMaximoPontos<0 || DesvioMaximoPontos<0)
   {
      Print("Parametros invalidos. LimiteGanhoCesta deve ser > 0 e FatorMultiplicacao entre 1 e 10.");
      return INIT_PARAMETERS_INCORRECT;
   }
   // Duas cestas simultaneas so existem em conta HEDGING. Em NETTING (B3) a
   // compra e a venda se anulariam: opera-se um lado so.
   contaNetting=((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   if(contaNetting && TipoTrades==TRADES_AMBOS)
   {
      Print("Conta NETTING (ex.: B3): escolha TipoTrades = Somente compras ou Somente vendas. 'Ambos' exige conta HEDGING.");
      return INIT_PARAMETERS_INCORRECT;
   }
   negociador.SetExpertMagicNumber((ulong)NumeroMagico);
   negociador.SetDeviationInPoints((ulong)DesvioMaximoPontos);
   negociador.SetTypeFillingBySymbol(_Symbol);
   negociador.LogLevel(LOG_LEVEL_ERRORS);

   prefixo="EA10_GRADE_"+IntegerToString(NumeroMagico)+"_";
   painelDisponivel=(ExibirPainel && (!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE)));
   picoTotal=AccountInfoDouble(ACCOUNT_EQUITY);
   if(MaximoOrdensPorCesta==0 && FatorMultiplicacao>1.0)
      Print("ATENCAO: martingale sem limite de ordens por cesta. Uma tendencia longa pode zerar a conta.");
   PrintFormat("EA10 Grade Hedge iniciado (%s): %s, tipo=%s, lote=%.2f, grade=%d pts, fator=%.2f, alvo cesta=%.2f",
               contaNetting?"NETTING":"HEDGING",_Symbol,EnumToString(TipoTrades),Lote,DistanciaGradePontos,FatorMultiplicacao,LimiteGanhoCesta);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int motivo)
{
   if(painelDisponivel) LimparPainel();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res)
{
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD) historicoSujo=true;
}

double OnTester()
{
   double ops=TesterStatistics(STAT_TRADES);
   double lucro=TesterStatistics(STAT_PROFIT);
   double dd=TesterStatistics(STAT_EQUITY_DD);
   double pf=TesterStatistics(STAT_PROFIT_FACTOR);
   if(ops<MinimoOperacoesOtimizacao || lucro<=0.0) return 0.0;
   if(dd<=0.0) dd=1.0;
   return (lucro/dd)*MathMin(pf,5.0);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!AmbientePermitido()) { estado="Bloqueado neste ambiente"; return; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED)) { estado="Algotrading desligado"; return; }

   AtualizarHistorico();
   AtualizarDrawdown();

   Cesta compras, vendas;
   LerCesta(POSITION_TYPE_BUY,compras);
   LerCesta(POSITION_TYPE_SELL,vendas);

   // Painel no maximo 1x por segundo.
   if(painelDisponivel && TimeCurrent()!=ultimoPainel) { ultimoPainel=TimeCurrent(); AtualizarPainel(compras,vendas); }

   // 1) Protecao de patrimonio: desliga o EA de vez.
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(!desligadoPorPatrimonio && StopPatrimonioPct>0 && picoTotal>0 && eq<=picoTotal*(1.0-StopPatrimonioPct/100.0))
   {
      desligadoPorPatrimonio=true;
      PrintFormat("STOP DE PATRIMONIO: %.2f caiu %.1f%% do pico %.2f. Fechando tudo e desligando.",eq,100*(picoTotal-eq)/picoTotal,picoTotal);
   }
   if(desligadoPorPatrimonio)
   {
      estado="DESLIGADO: stop de patrimonio";
      if(compras.qtd+vendas.qtd>0) FecharTudo("stop de patrimonio");
      return;
   }

   // 2) Horario de encerramento: fecha tudo e nao abre ate a meia-noite.
   if(minEncerrar>=0 && MinutoAtual()>=minEncerrar)
   {
      estado="Horario de encerramento";
      if(compras.qtd+vendas.qtd>0) FecharTudo("horario de encerramento");
      return;
   }

   // 3) Limites diarios (fechado no dia + aberto).
   datetime hoje=InicioDia(TimeCurrent());
   double resultadoDia=fechadoDia+compras.lucro+vendas.lucro;
   if(diaBloqueado!=hoje &&
      ((LimiteGanhoDiario>0 && resultadoDia>=LimiteGanhoDiario) ||
       (LimitePerdaDiario>0 && resultadoDia<=-LimitePerdaDiario)))
   {
      diaBloqueado=hoje;
      PrintFormat("Limite diario atingido (%.2f). Fechando tudo ate amanha.",resultadoDia);
   }
   if(diaBloqueado==hoje)
   {
      estado="Limite diario atingido";
      if(compras.qtd+vendas.qtd>0) FecharTudo("limite diario");
      return;
   }

   // 4) Alvo / stop de cada cesta. Depois de fechar, espera o proximo tick.
   bool fechou=false;
   if(compras.qtd>0 && compras.lucro>=LimiteGanhoCesta)
      { FecharCesta(POSITION_TYPE_BUY,StringFormat("alvo %.2f",compras.lucro)); fechou=true; }
   else if(compras.qtd>0 && LimitePerdaCesta>0 && compras.lucro<=-LimitePerdaCesta)
      { FecharCesta(POSITION_TYPE_BUY,StringFormat("stop %.2f",compras.lucro)); fechou=true; }
   if(vendas.qtd>0 && vendas.lucro>=LimiteGanhoCesta)
      { FecharCesta(POSITION_TYPE_SELL,StringFormat("alvo %.2f",vendas.lucro)); fechou=true; }
   else if(vendas.qtd>0 && LimitePerdaCesta>0 && vendas.lucro<=-LimitePerdaCesta)
      { FecharCesta(POSITION_TYPE_SELL,StringFormat("stop %.2f",vendas.lucro)); fechou=true; }
   if(fechou) return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<=0) return;
   bool operaCompra=(TipoTrades!=TRADES_VENDA);
   bool operaVenda=(TipoTrades!=TRADES_COMPRA);
   double distancia=DistanciaGradePontos*_Point;

   // 5) Grade: nova ordem quando o preco anda contra a ultima ordem da cesta.
   //    Continua fora da janela de envio (so novas cestas respeitam o horario).
   if(DistanciaGradePontos>0)
   {
      if(compras.qtd>0 && tick.ask<=compras.precoUltima-distancia)
      {
         if(MaximoOrdensPorCesta>0 && compras.qtd>=MaximoOrdensPorCesta) estado="Grade de compras no limite";
         else if(AbrirOrdem(POSITION_TYPE_BUY,compras.loteUltimo*FatorMultiplicacao,"EA10 grade C"+IntegerToString(compras.qtd+1)))
            estado=StringFormat("Grade compra #%d",compras.qtd+1);
      }
      if(vendas.qtd>0 && tick.bid>=vendas.precoUltima+distancia)
      {
         if(MaximoOrdensPorCesta>0 && vendas.qtd>=MaximoOrdensPorCesta) estado="Grade de vendas no limite";
         else if(AbrirOrdem(POSITION_TYPE_SELL,vendas.loteUltimo*FatorMultiplicacao,"EA10 grade V"+IntegerToString(vendas.qtd+1)))
            estado=StringFormat("Grade venda #%d",vendas.qtd+1);
      }
   }

   // 6) Novas cestas, somente dentro da janela de envio.
   if(!DentroDoHorarioDeEnvio()) { if(compras.qtd+vendas.qtd==0) estado="Fora do horario de envio"; return; }
   if(operaCompra && compras.qtd==0 && AbrirOrdem(POSITION_TYPE_BUY,Lote,"EA10 cesta C1")) estado="Nova cesta de compras";
   if(operaVenda && vendas.qtd==0 && AbrirOrdem(POSITION_TYPE_SELL,Lote,"EA10 cesta V1")) estado="Nova cesta de vendas";
}
//+------------------------------------------------------------------+
