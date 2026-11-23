//+------------------------------------------------------------------+
//| EA 09 - Rompimento ATR / Revisao para Strategy Tester (PT-BR)     |
//| Referencia: https://www.youtube.com/watch?v=JGzZKDFed54         |
//| IMPORTANTE: prototipo. Estrategia NAO extraida do video.         |
//| Compilacao e backtest no MetaEditor/MT5 sao necessarios.         |
//+------------------------------------------------------------------+
//| Alteracoes v2.20 (apos backtest WIN$ M1, 9 perdas seguidas):      |
//|  - Horario com minutos + zeragem diaria (day trade B3).           |
//|  - Canal so com barras do mesmo dia (ignora gap de abertura).     |
//|  - Espera N barras apos um stop (evita reentrada imediata).       |
//|  - Limite de perdas seguidas no dia.                              |
//|  - Stop minimo/maximo em pontos para o stop por ATR.              |
//|  - Trava de rebaixamento maximo (% do pico do patrimonio).        |
//|  - Limite de risco do lote fixo (% do patrimonio por operacao).   |
//|  - Diario mostra o risco em dinheiro e % de cada entrada.         |
//| Alteracoes v2.10 (em relacao a v2.00):                            |
//|  - Barra so e marcada como processada quando ATR/EMA/candles      |
//|    estao prontos (antes o sinal da barra era perdido).            |
//|  - Canal de referencia lido com uma unica chamada CopyRates.      |
//|  - Verifica modo de negociacao do simbolo (desativado, somente    |
//|    fechamento, somente compra, somente venda).                    |
//|  - Repeticao de envio em requote/preco alterado/sem cotacao.      |
//|  - HistorySelect com folga no fim (evita perder deal do tick).    |
//|  - Validacoes extras: break-even trava < inicio; ATR e pontos.   |
//|  - Fechamento no limite diario sem flood de mensagens no Diario.  |
//|  - Painel atualizado tambem quando o sinal e bloqueado.           |
//|  - OnTester com criterio personalizado para otimizacao.           |
//+------------------------------------------------------------------+
#property version   "2.20"
#property description "EA 09: prototipo de rompimento por ATR, com diagnosticos e painel em portugues. Nao e copia verificada do video."
#include <Trade/Trade.mqh>

enum ENUM_TIPO_STOP
{
   STOP_POR_ATR = 0,       // Stop e alvo por multiplos do ATR
   STOP_POR_PONTOS = 1     // Stop e alvo em pontos do ativo
};

input group "01 - TESTADOR E PERMISSOES"
input bool PermitirNoTestador = true;          // Ligado por padrao somente no testador
input bool PermitirEmDemo = false;            // Habilitar manualmente para conta demo
input bool PermitirEmContaReal = false;       // Protecao: conta real bloqueada por padrao
input long NumeroMagico = 2601122009;        // Identificador deste Expert Advisor
input ENUM_TIMEFRAMES PeriodoDosSinais = PERIOD_M5; // Periodo para analisar barras fechadas
input bool PermitirCompras = true;            // Autorizar entradas compradas
input bool PermitirVendas = true;             // Autorizar entradas vendidas
input int DesvioMaximoPontos = 20;            // Tolerancia de execucao, em pontos
input int TentativasDeEnvio = 3;              // Tentativas em requote/preco alterado (1 = sem repeticao)
input bool MostrarDiagnosticos = true;        // Imprimir sinais e bloqueios no Diario

input group "02 - ESTRATEGIA ATR (PROTOTIPO)"
input int PeriodoATR = 14;                    // Periodos do ATR
input int BarrasDeReferencia = 1;             // Maxima/minima das N barras anteriores
input double ExcessoRompimentoATR = 0.05;     // ATR alem da maxima/minima; 0 = sem excesso
input bool ExigirCandleNaDirecao = true;      // Compra: candle alta; venda: candle baixa
input bool HabilitarFiltroEMA = false;        // Filtro de tendencia adicional, opcional
input int PeriodoEMA = 50;                   // Periodos EMA usada no filtro

input group "03 - LOTE, STOP E ALVO"
input bool UsarLotePorRisco = false;          // Calcula lote por risco percentual
input double LoteFixo = 0.10;                // Lote solicitado para cada operacao
input bool AjustarLoteFixoAoMinimo = false;  // Se true, pode aumentar o volume solicitado
input double RiscoPorOperacaoPct = 0.50;      // Percentual do patrimonio arriscado ate SL
input ENUM_TIPO_STOP ModoStopAlvo = STOP_POR_ATR; // Metodo de calculo de SL/TP
input double StopMultiploATR = 1.50;         // Distancia do SL em ATRs
input double AlvoMultiploATR = 2.50;         // Distancia do TP em ATRs
input int StopLossPontos = 300;              // Usado somente se ModoStopAlvo = pontos
input int TakeProfitPontos = 600;            // Usado somente se ModoStopAlvo = pontos

input group "04 - HORARIO E SESSAO (padrao: B3 day trade)"
input int HoraInicioServidor = 9;            // Inicio das entradas (hora). Inicio = fim -> 24 horas
input int MinutoInicioServidor = 15;         // Inicio das entradas (minuto); evita o leilao/abertura
input int HoraFimServidor = 17;              // Fim das entradas (hora, exclusivo)
input int MinutoFimServidor = 0;             // Fim das entradas (minuto)
input bool EncerrarNoHorario = true;         // Zera posicoes deste EA no horario abaixo
input int HoraEncerramento = 17;             // Hora da zeragem diaria
input int MinutoEncerramento = 45;           // Minuto da zeragem diaria
input bool ExigirCanalDoMesmoDia = true;     // Ignora sinal se o canal usa barras do dia anterior (gap)

input group "05 - FILTROS E LIMITES"
input int SpreadMaximoPontos = 0;            // 0 desliga o filtro de spread
input int OperacoesMaximasDia = 0;           // 0 sem limite de entradas por dia
input int PerdasSeguidasMaximasDia = 3;      // Para de operar no dia apos N stops seguidos; 0 desliga
input int BarrasEsperaAposStop = 2;          // Barras de espera apos saida com perda; 0 desliga
input double PerdaMaximaDiaMoeda = 0.0;      // 0 desliga limite diario de perda
input double GanhoMaximoDiaMoeda = 0.0;      // 0 desliga limite diario de ganho
input bool FecharNoLimiteDiario = true;      // Fecha posicoes deste EA se limite atingido
input double RebaixamentoMaximoPct = 30.0;   // Desliga o EA se patrimonio cair X% do pico; 0 desliga
input bool BloquearSeExistePosicaoNoAtivo = true; // Protege contas NETTING

input group "06 - LIMITES DO STOP E DO RISCO"
input int StopMinimoPontos = 0;              // Stop ATR menor que isso e ampliado (alvo proporcional); 0 desliga
input int StopMaximoPontos = 0;              // Stop ATR maior que isso: entrada ignorada; 0 desliga
input double RiscoMaximoLoteFixoPct = 0.0;   // Lote fixo: ignora entrada se perda ate o SL > X% do patrimonio; 0 desliga

input group "07 - GERENCIAMENTO DE POSICOES"
input int BreakEvenInicioPontos = 0;          // 0 desliga break-even
input int BreakEvenTravaPontos = 0;           // Pontos positivos ao acionar (menor que o inicio)
input int TrailingInicioPontos = 0;           // 0 desliga trailing stop
input int TrailingDistanciaPontos = 0;        // 0 desliga trailing stop

input group "08 - PAINEL DE RESULTADOS"
input bool ExibirPainel = true;              // Visivel no grafico ou teste visual
input int PainelPosicaoX = 12;               // Distancia horizontal
input int PainelPosicaoY = 16;               // Distancia vertical

input group "09 - OTIMIZACAO (OnTester)"
input int MinimoOperacoesOtimizacao = 30;    // Abaixo disso o criterio personalizado retorna 0

CTrade negociador;
int handleATR = INVALID_HANDLE;
int handleEMA = INVALID_HANDLE;
datetime ultimaBarraProcessada = 0;
datetime diaBloqueado = 0;
bool fechamentoLimiteAvisado = false;
string estado = "Iniciando...";
string prefixo;
bool painelDisponivel = false;

// Indicadores de diagnostico, validos desde o inicio da execucao do EA.
long barrasProcessadas = 0;
long sinaisCompra = 0;
long sinaisVenda = 0;
long ordensEnviadas = 0;
long ordensRejeitadas = 0;
long bloqueiosPorFiltro = 0;

// Historico so e relido quando muda o dia ou ocorre uma transacao.
bool historicoSujo = true;
bool historicoDisponivel = false;
datetime diaDoHistorico = 0;
double resultadoDia = 0.0;
double resultadoTotal = 0.0;
int entradasDia = 0;
int saidasTotal = 0;
int saidasPositivas = 0;
int perdasSeguidasDia = 0;           // stops seguidos hoje (zera com saida positiva)
datetime ultimaSaidaComPerda = 0;    // horario da ultima saida negativa

// Trava de rebaixamento.
double picoPatrimonio = 0.0;
bool bloqueioPorRebaixamento = false;

// Resultado da leitura do sinal.
#define SINAL_SEM_DADOS  -99   // dados ainda nao prontos: tentar de novo na mesma barra

bool OperacoesPermitidasPeloAmbiente()
{
   if(MQLInfoInteger(MQL_TESTER)) return PermitirNoTestador;
   ENUM_ACCOUNT_TRADE_MODE modo = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(modo == ACCOUNT_TRADE_MODE_REAL) return PermitirEmContaReal;
   return PermitirEmDemo;
}

// Verifica se o simbolo aceita abrir posicao no lado solicitado.
bool SimboloPermiteLado(const int lado, string &motivo)
{
   ENUM_SYMBOL_TRADE_MODE modo=(ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   switch(modo)
   {
      case SYMBOL_TRADE_MODE_DISABLED:  motivo="Negociacao desativada no simbolo"; return false;
      case SYMBOL_TRADE_MODE_CLOSEONLY: motivo="Simbolo somente para fechamento"; return false;
      case SYMBOL_TRADE_MODE_LONGONLY:  if(lado<0){motivo="Simbolo aceita somente compras";return false;} break;
      case SYMBOL_TRADE_MODE_SHORTONLY: if(lado>0){motivo="Simbolo aceita somente vendas";return false;} break;
      default: break;
   }
   return true;
}

bool LerIndicador(const int handle, const int deslocamento, double &valor)
{
   if(handle == INVALID_HANDLE || BarsCalculated(handle) <= deslocamento)
      return false;
   double dados[];
   if(CopyBuffer(handle, 0, deslocamento, 1, dados) != 1)
      return false;
   valor = dados[0];
   return MathIsValidNumber(valor) && valor != EMPTY_VALUE && valor > 0.0;
}

// Analisa exclusivamente a ultima barra FECHADA (deslocamento=1).
// O canal e calculado com as N barras anteriores (deslocamentos 2..N+1), sem olhar para o futuro.
// Retorno: 1 compra, -1 venda, 0 sem sinal, SINAL_SEM_DADOS se dados ainda nao prontos.
int SinalATR(const datetime barraAtual, double &atrUsado, double &referenciaSuperior, double &referenciaInferior)
{
   atrUsado = 0.0;
   referenciaSuperior = 0.0;
   referenciaInferior = 0.0;

   // Copia de uma vez: barra fechada + N barras de referencia.
   MqlRates barras[];
   ArraySetAsSeries(barras, true);
   int necessarias = BarrasDeReferencia + 1;
   if(CopyRates(_Symbol, PeriodoDosSinais, 1, necessarias, barras) != necessarias)
   {
      estado = "Aguardando dados de candles";
      return SINAL_SEM_DADOS;
   }
   if(!LerIndicador(handleATR, 1, atrUsado))
   {
      estado = "Aguardando calculo do ATR";
      return SINAL_SEM_DADOS;
   }
   double ema = 0.0;
   if(HabilitarFiltroEMA && !LerIndicador(handleEMA, 1, ema))
   {
      estado = "Aguardando calculo da EMA";
      return SINAL_SEM_DADOS;
   }

   // Gap de abertura: se a barra mais antiga do canal for de outro dia, o
   // "rompimento" e so a diferenca entre o fechamento de ontem e a abertura de hoje.
   if(ExigirCanalDoMesmoDia)
   {
      datetime diaAtual = barraAtual - (barraAtual % 86400);
      datetime maisAntiga = barras[necessarias-1].time;
      if(maisAntiga - (maisAntiga % 86400) != diaAtual)
      {
         estado = "Canal com barras do dia anterior (gap)";
         return 0;
      }
   }

   // barras[0] = barra fechada (deslocamento 1); barras[1..N] = referencia.
   double maxima = -DBL_MAX;
   double minima = DBL_MAX;
   for(int i=1; i<necessarias; i++)
   {
      maxima = MathMax(maxima, barras[i].high);
      minima = MathMin(minima, barras[i].low);
   }
   referenciaSuperior = maxima + ExcessoRompimentoATR*atrUsado;
   referenciaInferior = minima - ExcessoRompimentoATR*atrUsado;

   MqlRates fechada = barras[0];
   bool compra = (fechada.close > referenciaSuperior);
   bool venda  = (fechada.close < referenciaInferior);
   if(ExigirCandleNaDirecao)
   {
      compra = compra && fechada.close > fechada.open;
      venda  = venda  && fechada.close < fechada.open;
   }
   if(HabilitarFiltroEMA)
   {
      compra = compra && fechada.close > ema;
      venda  = venda  && fechada.close < ema;
   }
   if(compra) return 1;
   if(venda) return -1;
   estado = "Sem rompimento ATR confirmado";
   return 0;
}

datetime InicioDia(const datetime momento)
{
   MqlDateTime d;
   TimeToStruct(momento, d);
   d.hour=0; d.min=0; d.sec=0;
   return StructToTime(d);
}

bool AtualizarHistorico()
{
   datetime dia = InicioDia(TimeCurrent());
   if(!historicoSujo && dia == diaDoHistorico)
      return historicoDisponivel;

   // Folga de 1 dia no fim para nao perder o deal executado no tick atual.
   if(!HistorySelect((datetime)0, TimeCurrent()+86400))
   {
      historicoDisponivel = false;
      estado = "Falha ao carregar historico";
      if(MostrarDiagnosticos) PrintFormat("Falha HistorySelect, erro %d", GetLastError());
      return false;
   }
   resultadoDia=0.0;
   resultadoTotal=0.0;
   entradasDia=0;
   saidasTotal=0;
   saidasPositivas=0;
   perdasSeguidasDia=0;
   ultimaSaidaComPerda=0;
   int negocios = HistoryDealsTotal();
   for(int i=0; i<negocios; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != NumeroMagico) continue;
      long tipo = HistoryDealGetInteger(ticket, DEAL_TYPE);
      if(tipo != DEAL_TYPE_BUY && tipo != DEAL_TYPE_SELL) continue;
      datetime quando = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      double resultado = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                       + HistoryDealGetDouble(ticket, DEAL_COMMISSION)
                       + HistoryDealGetDouble(ticket, DEAL_SWAP)
                       + HistoryDealGetDouble(ticket, DEAL_FEE);
      resultadoTotal += resultado;
      if(quando >= dia) resultadoDia += resultado;
      long entrada = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(quando>=dia && (entrada==DEAL_ENTRY_IN || entrada==DEAL_ENTRY_INOUT))
         entradasDia++;
      if(entrada==DEAL_ENTRY_OUT || entrada==DEAL_ENTRY_OUT_BY || entrada==DEAL_ENTRY_INOUT)
      {
         saidasTotal++;
         if(resultado>0.0) saidasPositivas++;
         if(resultado<0.0 && quando>ultimaSaidaComPerda) ultimaSaidaComPerda=quando;
         if(quando>=dia)
         {
            if(resultado<0.0) perdasSeguidasDia++;
            else if(resultado>0.0) perdasSeguidasDia=0;
         }
      }
   }
   diaDoHistorico = dia;
   historicoSujo = false;
   historicoDisponivel = true;
   return true;
}

bool PosicaoDoEA()
{
   return PositionGetString(POSITION_SYMBOL) == _Symbol &&
          PositionGetInteger(POSITION_MAGIC) == NumeroMagico;
}

int QuantidadeDePosicoes()
{
   int q=0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket>0 && PositionSelectByTicket(ticket) && PosicaoDoEA()) q++;
   }
   return q;
}

double LucroEmAberto()
{
   double lucro=0.0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket>0 && PositionSelectByTicket(ticket) && PosicaoDoEA())
         lucro += PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   }
   return lucro;
}

bool ExisteQualquerPosicaoNoSimbolo()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket>0 && PositionSelectByTicket(ticket) &&
         PositionGetString(POSITION_SYMBOL)==_Symbol) return true;
   }
   return false;
}

int MinutoDoDia(const datetime momento)
{
   MqlDateTime d;
   TimeToStruct(momento, d);
   return d.hour*60 + d.min;
}

// Janela de entradas [inicio, fim). Inicio = fim -> 24 horas.
bool DentroDoHorario()
{
   int inicio = HoraInicioServidor*60 + MinutoInicioServidor;
   int fim = HoraFimServidor*60 + MinutoFimServidor;
   if(inicio == fim) return true;
   int agora = MinutoDoDia(TimeCurrent());
   if(inicio < fim) return agora >= inicio && agora < fim;
   return agora >= inicio || agora < fim;
}

// Janela de zeragem [encerramento, inicio das entradas). Nela o EA fecha
// suas posicoes e nao abre novas.
bool HorarioDeEncerramento()
{
   if(!EncerrarNoHorario) return false;
   int encerramento = HoraEncerramento*60 + MinutoEncerramento;
   int inicio = HoraInicioServidor*60 + MinutoInicioServidor;
   if(encerramento == inicio) return false;
   int agora = MinutoDoDia(TimeCurrent());
   if(encerramento < inicio) return agora >= encerramento && agora < inicio;
   return agora >= encerramento || agora < inicio;
}

double PrecoAjustado(const double preco, const int direcao)
{
   double passo = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(passo<=0.0) passo=_Point;
   double unidades=preco/passo;
   if(direcao<0) unidades=MathFloor(unidades+1e-9);
   else if(direcao>0) unidades=MathCeil(unidades-1e-9);
   else unidades=MathRound(unidades);
   return NormalizeDouble(unidades*passo, _Digits);
}

double LoteNormalizado(const double desejado, const bool risco)
{
   double minimo=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maximo=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double passo=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(minimo<=0 || maximo<minimo || passo<=0 || desejado<=0) return 0.0;
   if(desejado<minimo && (risco || !AjustarLoteFixoAoMinimo)) return 0.0; // nao ultrapassa risco nem lote sem autorizacao
   double volume=MathMax(minimo,MathMin(desejado,maximo));
   volume=minimo+MathFloor((volume-minimo)/passo+1e-9)*passo;
   volume=NormalizeDouble(volume,8);
   if(volume<minimo || volume>maximo || volume<=0) return 0.0;
   return volume;
}

void FecharPosicoesDoEA()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket) || !PosicaoDoEA()) continue;
      bool ok=negociador.PositionClose(ticket);
      uint retorno=negociador.ResultRetcode();
      if(!ok || (retorno!=TRADE_RETCODE_DONE && retorno!=TRADE_RETCODE_DONE_PARTIAL))
      {
         // Evita repetir a mesma mensagem a cada tick (ex.: mercado fechado).
         if(!fechamentoLimiteAvisado)
            PrintFormat("ERRO AO FECHAR posicao %I64u: %s",ticket,negociador.ResultRetcodeDescription());
         fechamentoLimiteAvisado=true;
      }
      else
         historicoSujo=true;
   }
}

void GerenciarPosicoes()
{
   if(BreakEvenInicioPontos<=0 && (TrailingInicioPontos<=0 || TrailingDistanciaPontos<=0)) return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.bid<=0 || tick.ask<=0) return;
   int stopLevel=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   int freezeLevel=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   double tamanhoTick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tamanhoTick<=0) tamanhoTick=_Point;
   double afastamento=MathMax(stopLevel,freezeLevel)*_Point+tamanhoTick;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket) || !PosicaoDoEA()) continue;
      bool comprado=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      double entrada=PositionGetDouble(POSITION_PRICE_OPEN);
      double slAtual=PositionGetDouble(POSITION_SL);
      double tp=PositionGetDouble(POSITION_TP);
      double precoAtual=comprado?tick.bid:tick.ask;
      double ganhoPontos=(comprado?precoAtual-entrada:entrada-precoAtual)/_Point;
      double novoSL=slAtual;
      if(BreakEvenInicioPontos>0 && ganhoPontos>=BreakEvenInicioPontos)
      {
         double candidato=entrada+(comprado?1.0:-1.0)*BreakEvenTravaPontos*_Point;
         if(novoSL<=0 || (comprado && candidato>novoSL) || (!comprado && candidato<novoSL)) novoSL=candidato;
      }
      if(TrailingInicioPontos>0 && TrailingDistanciaPontos>0 && ganhoPontos>=TrailingInicioPontos)
      {
         double candidato=precoAtual+(comprado?-1.0:1.0)*TrailingDistanciaPontos*_Point;
         if(novoSL<=0 || (comprado && candidato>novoSL) || (!comprado && candidato<novoSL)) novoSL=candidato;
      }
      if(novoSL<=0) continue;
      // TP dentro do freeze level impede a modificacao: nao insiste.
      if(tp>0 && freezeLevel>0 && MathAbs(precoAtual-tp)<=freezeLevel*_Point) continue;
      if(comprado)
      {
         novoSL=PrecoAjustado(MathMin(novoSL,tick.bid-afastamento),-1);
         if(novoSL<=0 || (slAtual>0 && novoSL<=slAtual+tamanhoTick*0.5)) continue;
      }
      else
      {
         novoSL=PrecoAjustado(MathMax(novoSL,tick.ask+afastamento),1);
         if(novoSL<=0 || (slAtual>0 && novoSL>=slAtual-tamanhoTick*0.5)) continue;
      }
      bool ok=negociador.PositionModify(ticket,novoSL,tp);
      uint retorno=negociador.ResultRetcode();
      if((!ok || retorno!=TRADE_RETCODE_DONE) && MostrarDiagnosticos)
         PrintFormat("Falha ao alterar stop %I64u: %s",ticket,negociador.ResultRetcodeDescription());
   }
}

// Retcodes em que vale a pena repetir o envio com preco atualizado.
bool RetcodeRepetivel(const uint codigo)
{
   return codigo==TRADE_RETCODE_REQUOTE || codigo==TRADE_RETCODE_PRICE_CHANGED ||
          codigo==TRADE_RETCODE_PRICE_OFF || codigo==TRADE_RETCODE_CONNECTION ||
          codigo==TRADE_RETCODE_TIMEOUT;
}

// Calcula SL/TP a partir do tick atual. Retorna false se ficarem invalidos.
bool CalcularStops(const int lado, const double atr, const MqlTick &tick,
                   double &entrada, double &sl, double &tp)
{
   double distanciaSL=(ModoStopAlvo==STOP_POR_ATR ? StopMultiploATR*atr : StopLossPontos*_Point);
   double distanciaTP=(ModoStopAlvo==STOP_POR_ATR ? AlvoMultiploATR*atr : TakeProfitPontos*_Point);
   if(distanciaSL<=0 || distanciaTP<=0) {estado="Distancias SL/TP invalidas";return false;}
   if(ModoStopAlvo==STOP_POR_ATR)
   {
      // ATR baixo gera stop curto demais (ruido); amplia SL e TP na mesma proporcao.
      if(StopMinimoPontos>0 && distanciaSL < StopMinimoPontos*_Point)
      {
         double fator = StopMinimoPontos*_Point/distanciaSL;
         distanciaSL *= fator;
         distanciaTP *= fator;
      }
      if(StopMaximoPontos>0 && distanciaSL > StopMaximoPontos*_Point)
      {
         estado=StringFormat("Stop ATR %.0f pts acima do maximo %d",distanciaSL/_Point,StopMaximoPontos);
         return false;
      }
   }
   double passo=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(passo<=0) passo=_Point;
   double minStop=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point+passo;
   entrada=(lado>0?tick.ask:tick.bid);
   if(lado>0)
   {
      sl=PrecoAjustado(MathMin(entrada-distanciaSL,tick.bid-minStop),-1);
      tp=PrecoAjustado(MathMax(entrada+distanciaTP,tick.bid+minStop),1);
   }
   else
   {
      sl=PrecoAjustado(MathMax(entrada+distanciaSL,tick.ask+minStop),1);
      tp=PrecoAjustado(MathMin(entrada-distanciaTP,tick.ask-minStop),-1);
   }
   if(sl<=0 || tp<=0 || (lado>0 && (sl>=entrada || tp<=entrada)) ||
      (lado<0 && (sl<=entrada || tp>=entrada)))
   {
      estado="SL/TP invalidos para o ativo";
      return false;
   }
   return true;
}

bool EnviarOrdem(const int lado, const double atr)
{
   string motivo="";
   if(!SimboloPermiteLado(lado,motivo)) {estado=motivo;return false;}

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<=0 || tick.ask<tick.bid)
   {
      estado="Cotacoes bid/ask invalidas";
      return false;
   }
   double entrada,sl,tp;
   if(!CalcularStops(lado,atr,tick,entrada,sl,tp)) return false;

   ENUM_ORDER_TYPE tipo=(lado>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double solicitado=LoteFixo;
   if(UsarLotePorRisco)
   {
      double perdaPorLote=0.0;
      if(!OrderCalcProfit(tipo,_Symbol,1.0,entrada,sl,perdaPorLote) || perdaPorLote>=0.0)
      {
         estado="Erro ao calcular risco por lote";
         return false;
      }
      solicitado=AccountInfoDouble(ACCOUNT_EQUITY)*RiscoPorOperacaoPct/100.0/MathAbs(perdaPorLote);
   }
   double lote=LoteNormalizado(solicitado,UsarLotePorRisco);
   if(lote<=0)
   {
      estado="Lote nao permitido ou risco abaixo do minimo";
      if(MostrarDiagnosticos) PrintFormat("Lote calculado %.6f, minimo %.6f, passo %.6f",solicitado,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP));
      return false;
   }
   // Risco real da entrada (perda ate o SL), em dinheiro e % do patrimonio.
   double patrimonio=AccountInfoDouble(ACCOUNT_EQUITY);
   double perdaAteSL=0.0;
   double riscoPct=0.0;
   if(OrderCalcProfit(tipo,_Symbol,lote,entrada,sl,perdaAteSL) && patrimonio>0.0)
      riscoPct=100.0*MathAbs(perdaAteSL)/patrimonio;
   if(!UsarLotePorRisco && RiscoMaximoLoteFixoPct>0.0 && riscoPct>RiscoMaximoLoteFixoPct)
   {
      estado=StringFormat("Risco %.1f%% > limite %.1f%%",riscoPct,RiscoMaximoLoteFixoPct);
      if(MostrarDiagnosticos)
         PrintFormat("Entrada ignorada: perda ate o SL %.2f = %.1f%% do patrimonio (limite %.1f%%)",
                     MathAbs(perdaAteSL),riscoPct,RiscoMaximoLoteFixoPct);
      return false;
   }
   double margem=0.0;
   if(!OrderCalcMargin(tipo,_Symbol,lote,entrada,margem))
   {
      estado="Erro no calculo de margem";
      return false;
   }
   if(margem>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   {
      estado="Margem insuficiente";
      return false;
   }

   string comentario="EA09 ATR prototipo v2.20";
   int tentativas=MathMax(1,TentativasDeEnvio);
   uint resposta=0;
   bool enviado=false;
   for(int t=1; t<=tentativas; t++)
   {
      enviado=(lado>0 ? negociador.Buy(lote,_Symbol,0.0,sl,tp,comentario)
                      : negociador.Sell(lote,_Symbol,0.0,sl,tp,comentario));
      resposta=negociador.ResultRetcode();
      if(enviado && (resposta==TRADE_RETCODE_DONE || resposta==TRADE_RETCODE_DONE_PARTIAL)) break;
      enviado=false;
      if(t==tentativas || !RetcodeRepetivel(resposta)) break;
      if(MostrarDiagnosticos)
         PrintFormat("Tentativa %d/%d recusada (%s); recalculando precos.",t,tentativas,negociador.ResultRetcodeDescription());
      if(!MQLInfoInteger(MQL_TESTER)) Sleep(200);
      // Recalcula SL/TP com o tick novo para manter as distancias.
      if(!SymbolInfoTick(_Symbol,tick) || !CalcularStops(lado,atr,tick,entrada,sl,tp)) break;
   }
   if(!enviado)
   {
      ordensRejeitadas++;
      estado="Ordem recusada: "+negociador.ResultRetcodeDescription();
      PrintFormat("ENTRADA RECUSADA: retcode=%u (%s), lote=%.4f, SL=%.5f TP=%.5f",resposta,negociador.ResultRetcodeDescription(),lote,sl,tp);
      return false;
   }
   ordensEnviadas++;
   historicoSujo=true;
   estado=(lado>0?"COMPRA executada":"VENDA executada");
   if(MostrarDiagnosticos)
      PrintFormat("%s: lote %.4f, SL %.5f, TP %.5f, ATR %.6f, risco %.2f (%.1f%% do patrimonio)",
                  estado,lote,sl,tp,atr,MathAbs(perdaAteSL),riscoPct);
   return true;
}

void LimparPainel()
{
   int n=ObjectsTotal(0,0,-1);
   for(int i=n-1; i>=0; i--)
   {
      string nome=ObjectName(0,i,0,-1);
      if(StringFind(nome,prefixo)==0) ObjectDelete(0,nome);
   }
}

void LinhaPainel(const int linha, const string texto, const color cor)
{
   string nome=prefixo+"LINHA_"+IntegerToString(linha);
   if(ObjectFind(0,nome)<0) ObjectCreate(0,nome,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,nome,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,nome,OBJPROP_XDISTANCE,PainelPosicaoX+12);
   ObjectSetInteger(0,nome,OBJPROP_YDISTANCE,PainelPosicaoY+10+linha*20);
   ObjectSetInteger(0,nome,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,nome,OBJPROP_COLOR,cor);
   ObjectSetString(0,nome,OBJPROP_FONT,"Consolas");
   ObjectSetString(0,nome,OBJPROP_TEXT,texto);
   ObjectSetInteger(0,nome,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,nome,OBJPROP_HIDDEN,true);
}

void AtualizarPainel()
{
   if(!painelDisponivel) return;
   AtualizarHistorico();
   string fundo=prefixo+"FUNDO";
   if(ObjectFind(0,fundo)<0) ObjectCreate(0,fundo,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,fundo,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,fundo,OBJPROP_XDISTANCE,PainelPosicaoX);
   ObjectSetInteger(0,fundo,OBJPROP_YDISTANCE,PainelPosicaoY);
   ObjectSetInteger(0,fundo,OBJPROP_XSIZE,440);
   ObjectSetInteger(0,fundo,OBJPROP_YSIZE,325);
   ObjectSetInteger(0,fundo,OBJPROP_BGCOLOR,C'18,27,39');
   ObjectSetInteger(0,fundo,OBJPROP_COLOR,C'52,79,101');
   ObjectSetInteger(0,fundo,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,fundo,OBJPROP_HIDDEN,true);
   double flutuante=LucroEmAberto();
   double taxa=(saidasTotal>0?100.0*saidasPositivas/saidasTotal:0.0);
   MqlTick tick;
   double spread=0;
   if(SymbolInfoTick(_Symbol,tick) && tick.ask>=tick.bid) spread=(tick.ask-tick.bid)/_Point;
   bool permitido=OperacoesPermitidasPeloAmbiente();
   LinhaPainel(0,"EA 09 | ROMPIMENTO ATR | REVISAO v2.20",clrWhite);
   LinhaPainel(1,"MODELO PROVISORIO - VIDEO NAO VERIFICADO",C'255,189,84');
   LinhaPainel(2,"Ativo: "+_Symbol+" | Periodo: "+EnumToString(PeriodoDosSinais),C'210,225,240');
   LinhaPainel(3,"Entradas: "+(permitido?"AUTORIZADAS":"BLOQUEADAS"),permitido?clrLime:clrOrange);
   LinhaPainel(4,"Saldo: "+DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2)+" | Patrimonio: "+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2),clrWhite);
   LinhaPainel(5,"Resultado do dia: "+DoubleToString(resultadoDia,2),resultadoDia>=0?clrLime:clrTomato);
   LinhaPainel(6,"Resultado acumulado: "+DoubleToString(resultadoTotal,2),resultadoTotal>=0?clrLime:clrTomato);
   LinhaPainel(7,"Flutuante: "+DoubleToString(flutuante,2)+" | Posicoes: "+IntegerToString(QuantidadeDePosicoes()),clrWhite);
   LinhaPainel(8,"Entradas hoje: "+IntegerToString(entradasDia)+" | Saidas: "+IntegerToString(saidasTotal),clrWhite);
   LinhaPainel(9,"Taxa de saidas positivas: "+DoubleToString(taxa,1)+"%",clrWhite);
   LinhaPainel(10,"Barras: "+IntegerToString(barrasProcessadas)+" | Sinais C/V: "+IntegerToString(sinaisCompra)+"/"+IntegerToString(sinaisVenda),clrWhite);
   LinhaPainel(11,"Ordens enviadas: "+IntegerToString(ordensEnviadas)+" | Rejeitadas: "+IntegerToString(ordensRejeitadas),clrWhite);
   LinhaPainel(12,"Bloqueios por filtro: "+IntegerToString(bloqueiosPorFiltro)+" | Spread: "+DoubleToString(spread,1),clrWhite);
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   double ddPico=(picoPatrimonio>0.0?100.0*(picoPatrimonio-eq)/picoPatrimonio:0.0);
   LinhaPainel(13,"Stops seguidos hoje: "+IntegerToString(perdasSeguidasDia)+" | Queda do pico: "+DoubleToString(MathMax(ddPico,0.0),1)+"%",
               bloqueioPorRebaixamento?clrTomato:clrWhite);
   LinhaPainel(14,"Estado: "+estado,C'210,225,240');
   ChartRedraw(0);
}

// Registra um bloqueio de filtro e atualiza o painel.
void Bloquear(const string motivo, const bool imprimir=false)
{
   estado=motivo;
   bloqueiosPorFiltro++;
   if(imprimir && MostrarDiagnosticos) Print("Sinal bloqueado: ",motivo);
   AtualizarPainel();
}

int OnInit()
{
   bool parametrosOk = true;
   if(NumeroMagico<=0 || PeriodoATR<2 || BarrasDeReferencia<1 || BarrasDeReferencia>1000 ||
      ExcessoRompimentoATR<0.0 || PeriodoEMA<2 || LoteFixo<=0.0 ||
      RiscoPorOperacaoPct<=0.0 || RiscoPorOperacaoPct>100.0 ||
      SpreadMaximoPontos<0 || DesvioMaximoPontos<0 || OperacoesMaximasDia<0 || TentativasDeEnvio<1 ||
      HoraInicioServidor<0 || HoraInicioServidor>23 || HoraFimServidor<0 || HoraFimServidor>23 ||
      MinutoInicioServidor<0 || MinutoInicioServidor>59 || MinutoFimServidor<0 || MinutoFimServidor>59 ||
      HoraEncerramento<0 || HoraEncerramento>23 || MinutoEncerramento<0 || MinutoEncerramento>59 ||
      PerdasSeguidasMaximasDia<0 || BarrasEsperaAposStop<0 ||
      RebaixamentoMaximoPct<0.0 || RebaixamentoMaximoPct>=100.0 ||
      StopMinimoPontos<0 || StopMaximoPontos<0 || RiscoMaximoLoteFixoPct<0.0 ||
      PerdaMaximaDiaMoeda<0.0 || GanhoMaximoDiaMoeda<0.0 || MinimoOperacoesOtimizacao<0 ||
      BreakEvenInicioPontos<0 || BreakEvenTravaPontos<0 || TrailingInicioPontos<0 || TrailingDistanciaPontos<0)
      parametrosOk=false;
   // Somente os parametros do modo escolhido precisam ser validos.
   if(ModoStopAlvo==STOP_POR_ATR && (StopMultiploATR<=0.0 || AlvoMultiploATR<=0.0)) parametrosOk=false;
   if(ModoStopAlvo==STOP_POR_PONTOS && (StopLossPontos<=0 || TakeProfitPontos<=0)) parametrosOk=false;
   // Trava do break-even acima do gatilho colocaria o SL do lado errado do preco.
   if(BreakEvenInicioPontos>0 && BreakEvenTravaPontos>=BreakEvenInicioPontos) parametrosOk=false;
   if(StopMinimoPontos>0 && StopMaximoPontos>0 && StopMinimoPontos>StopMaximoPontos) parametrosOk=false;
   if(!parametrosOk)
   {
      Print("Parametros invalidos. Verifique o grupo correspondente.");
      return INIT_PARAMETERS_INCORRECT;
   }
   negociador.SetExpertMagicNumber((ulong)NumeroMagico);
   negociador.SetDeviationInPoints((ulong)DesvioMaximoPontos);
   negociador.SetTypeFillingBySymbol(_Symbol);
   negociador.SetAsyncMode(false);
   negociador.LogLevel(LOG_LEVEL_ERRORS);
   handleATR=iATR(_Symbol,PeriodoDosSinais,PeriodoATR);
   if(handleATR==INVALID_HANDLE)
   {
      PrintFormat("ERRO: nao foi possivel criar ATR. GetLastError()=%d",GetLastError());
      return INIT_FAILED;
   }
   if(HabilitarFiltroEMA)
   {
      handleEMA=iMA(_Symbol,PeriodoDosSinais,PeriodoEMA,0,MODE_EMA,PRICE_CLOSE);
      if(handleEMA==INVALID_HANDLE)
      {
         PrintFormat("ERRO: nao foi possivel criar EMA. GetLastError()=%d",GetLastError());
         IndicatorRelease(handleATR);
         handleATR=INVALID_HANDLE;
         return INIT_FAILED;
      }
   }
   picoPatrimonio=AccountInfoDouble(ACCOUNT_EQUITY);
   bloqueioPorRebaixamento=false;
   // Nao entra no meio da barra em andamento ao anexar o EA.
   ultimaBarraProcessada=iTime(_Symbol,PeriodoDosSinais,0);
   prefixo="EA09_ATR_V2_"+IntegerToString(NumeroMagico)+"_";
   painelDisponivel=(ExibirPainel && (!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE)));
   if(painelDisponivel) EventSetTimer(5);
   estado=(OperacoesPermitidasPeloAmbiente()?"Pronto para teste":"Entradas bloqueadas neste ambiente");
   Print("EA09 ATR v2.20 inicializado. PERMISSAO=",OperacoesPermitidasPeloAmbiente(),
         ", Testador=",MQLInfoInteger(MQL_TESTER),", Simbolo=",_Symbol,
         ", Timeframe=",EnumToString(PeriodoDosSinais),
         ". Estrategia prototipo, NAO extraida do video.");
   AtualizarPainel();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int motivo)
{
   if(painelDisponivel) EventKillTimer();
   if(handleATR!=INVALID_HANDLE) IndicatorRelease(handleATR);
   if(handleEMA!=INVALID_HANDLE) IndicatorRelease(handleEMA);
   if(painelDisponivel) LimparPainel();
   PrintFormat("RESUMO EA09 v2.20: barras=%I64d, sinais compra=%I64d, sinais venda=%I64d, ordens=%I64d, rejeicoes=%I64d, bloqueios=%I64d, ultimo estado=%s",
               barrasProcessadas, sinaisCompra, sinaisVenda, ordensEnviadas, ordensRejeitadas, bloqueiosPorFiltro, estado);
}

void OnTimer() { AtualizarPainel(); }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD) historicoSujo=true;
}

// Criterio personalizado (Otimizacao > "Custom max"):
// fator de recuperacao ponderado pelo fator de lucro; 0 se houver poucas operacoes.
double OnTester()
{
   double operacoes=TesterStatistics(STAT_TRADES);
   double lucro=TesterStatistics(STAT_PROFIT);
   double dd=TesterStatistics(STAT_EQUITY_DD);
   double pf=TesterStatistics(STAT_PROFIT_FACTOR);
   if(operacoes<MinimoOperacoesOtimizacao || lucro<=0.0) return 0.0;
   if(dd<=0.0) dd=1.0;
   return (lucro/dd)*MathMin(pf,5.0);
}

void OnTick()
{
   if(!OperacoesPermitidasPeloAmbiente())
   {
      estado="Bloqueado: habilite o ambiente desejado";
      return;
   }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      estado="Negociacao desativada no terminal ou conta";
      return;
   }
   GerenciarPosicoes();
   if(!AtualizarHistorico()) return;
   if(QuantidadeDePosicoes()==0) fechamentoLimiteAvisado=false;

   // Trava de rebaixamento: patrimonio caiu X% do maior valor ja visto.
   double patrimonio=AccountInfoDouble(ACCOUNT_EQUITY);
   if(patrimonio>picoPatrimonio) picoPatrimonio=patrimonio;
   if(!bloqueioPorRebaixamento && RebaixamentoMaximoPct>0.0 && picoPatrimonio>0.0 &&
      patrimonio<=picoPatrimonio*(1.0-RebaixamentoMaximoPct/100.0))
   {
      bloqueioPorRebaixamento=true;
      PrintFormat("TRAVA DE REBAIXAMENTO: patrimonio %.2f caiu %.1f%% do pico %.2f. EA nao abrira novas entradas.",
                  patrimonio,100.0*(picoPatrimonio-patrimonio)/picoPatrimonio,picoPatrimonio);
   }
   if(bloqueioPorRebaixamento)
   {
      estado="Desligado: rebaixamento maximo atingido";
      if(QuantidadeDePosicoes()>0) FecharPosicoesDoEA();
      return;
   }

   // Zeragem diaria (day trade): fecha posicoes e nao abre novas ate o proximo inicio.
   if(HorarioDeEncerramento())
   {
      estado="Horario de zeragem: sem novas entradas";
      if(QuantidadeDePosicoes()>0) FecharPosicoesDoEA();
      return;
   }

   datetime hoje=InicioDia(TimeCurrent());
   if(diaBloqueado!=0 && diaBloqueado!=hoje)
   {
      diaBloqueado=0;
      fechamentoLimiteAvisado=false;
   }
   double lucroMonitorado=resultadoDia+LucroEmAberto();
   if(diaBloqueado!=hoje &&
      ((PerdaMaximaDiaMoeda>0 && lucroMonitorado<=-PerdaMaximaDiaMoeda) ||
       (GanhoMaximoDiaMoeda>0 && lucroMonitorado>=GanhoMaximoDiaMoeda)))
   {
      diaBloqueado=hoje;
      if(MostrarDiagnosticos) PrintFormat("Limite financeiro diario atingido: %.2f",lucroMonitorado);
   }
   if(diaBloqueado==hoje)
   {
      estado="Limite financeiro do dia atingido";
      if(FecharNoLimiteDiario && QuantidadeDePosicoes()>0) FecharPosicoesDoEA();
      return;
   }

   datetime barra=iTime(_Symbol,PeriodoDosSinais,0);
   if(barra==0 || barra==ultimaBarraProcessada) return;

   double atr=0.0,superior=0.0,inferior=0.0;
   int sinal=SinalATR(barra,atr,superior,inferior);
   // Dados ainda nao prontos: NAO consome a barra, tenta de novo no proximo tick.
   if(sinal==SINAL_SEM_DADOS) return;

   ultimaBarraProcessada=barra;
   barrasProcessadas++;
   if(sinal==0) { AtualizarPainel(); return; }
   if(sinal>0) sinaisCompra++; else sinaisVenda++;
   if(MostrarDiagnosticos)
      PrintFormat("SINAL ATR %s: ATR=%.6f, rompimento acima %.6f / abaixo %.6f, barra=%s",
                  sinal>0?"COMPRA":"VENDA",atr,superior,inferior,TimeToString(barra,TIME_DATE|TIME_MINUTES));

   if(sinal>0 && !PermitirCompras) {Bloquear("Compras desativadas");return;}
   if(sinal<0 && !PermitirVendas)  {Bloquear("Vendas desativadas");return;}
   if(BloquearSeExistePosicaoNoAtivo && ExisteQualquerPosicaoNoSimbolo())
      {Bloquear("Ja existe posicao neste ativo");return;}
   if(!BloquearSeExistePosicaoNoAtivo && QuantidadeDePosicoes()>0)
      {Bloquear("Ja existe posicao deste robo");return;}
   if(OperacoesMaximasDia>0 && entradasDia>=OperacoesMaximasDia)
      {Bloquear("Limite de entradas do dia");return;}
   if(PerdasSeguidasMaximasDia>0 && perdasSeguidasDia>=PerdasSeguidasMaximasDia)
      {Bloquear(StringFormat("%d stops seguidos hoje",perdasSeguidasDia),true);return;}
   if(BarrasEsperaAposStop>0 && ultimaSaidaComPerda>0 &&
      (long)(barra-ultimaSaidaComPerda) < (long)BarrasEsperaAposStop*PeriodSeconds(PeriodoDosSinais))
      {Bloquear("Espera apos stop",true);return;}
   if(!DentroDoHorario())
      {Bloquear("Fora do horario do servidor",true);return;}
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.ask<=0 || tick.bid<=0)
      {Bloquear("Preco indisponivel");return;}
   double spread=(tick.ask-tick.bid)/_Point;
   if(SpreadMaximoPontos>0 && spread>SpreadMaximoPontos)
   {
      Bloquear(StringFormat("Spread %.1f > limite %d",spread,SpreadMaximoPontos),true);
      return;
   }
   if(!EnviarOrdem(sinal,atr) && MostrarDiagnosticos) Print("Sinal existente, ordem nao executada: ",estado);
   AtualizarPainel();
}
//+------------------------------------------------------------------+
