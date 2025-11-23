#include <postgres.h>
#include <fmgr.h>

#include "commands/explain.h"
#include "commands/explain_format.h"
#include "commands/explain_state.h"
#include "executor/executor.h"
#include "executor/execExpr.h"
#include "nodes/execnodes.h"
#include "nodes/makefuncs.h"
#include "nodes/pg_list.h"
#include "jit/jit.h"
#include "utils/guc.h"
#include "utils/ruleutils.h"

PG_MODULE_MAGIC;

extern PGDLLEXPORT void		_PG_init(void);

/// Registers the previous `ExecInitQual` hook.
static ExecInitQual_hook_type prev_ExecInitQual_hook = NULL;
/// Registers the previous `prev_explain_per_node_hook` hook.
static explain_per_node_hook_type prev_explain_per_node_hook = NULL;

static bool pg_feedback_enabled = false;


typedef struct pg_feedback_EvalFuncWithInstr {
	/// Previous private state of the evaluate function.
	void 	*private_state;
	/// Previous registered evaulate function.
	ExprStateEvalFunc evaluate_with_instr;
} pg_feedback_EvalFuncWithInstr;

/// Execute the instrumented evaluate function, then extract results.
/// See `pg_feedback_ExecInitQual` for how the predicate evaluation function is instrumented.
static Datum pg_feedback_evalfunc(ExprState *state, ExprContext *econtext, bool *isnull) {
	Datum result;
	int qual_index;
	pg_feedback_EvalFuncWithInstr *private = state->evalfunc_private;
	state->evalfunc_private = private->private_state;
	state->evalfunc = private->evaluate_with_instr;

	result = state->evalfunc(state, econtext, isnull);
	qual_index = DatumGetInt32(result);

	if (qual_index > 0 && state->parent)  {
		// Record instrumentation count.
		InstrRecordPerQualFiltered(state->parent, Min(qual_index, MAX_QUALS) - 1, 1);
	} 
	private->private_state = state->evalfunc_private;
	private->evaluate_with_instr = state->evalfunc;
	state->evalfunc_private = private;
	state->evalfunc = pg_feedback_evalfunc;
	*isnull = false;
	return	BoolGetDatum(qual_index == 0);
}

/// The instrumented evaluation function returns the index of the predicate
/// in the conjunctive clause if 
static ExprState *
pg_feedback_ExecInitQual(List *qual, PlanState *parent) {
	ExprState  *state;
	ExprEvalStep scratch = {0};
	List	   *adjust_jumps = NIL;
	int qual_index = 0;
	pg_feedback_EvalFuncWithInstr *private;

	if (!pg_feedback_enabled || parent == NULL) {
    	elog(LOG, "[pg_feedback_ExecInitQual] -- use standard_ExecInitQual");
		return standard_ExecInitQual(qual, parent);
	}

	/* short-circuit (here and in ExecQual) for empty restriction list */
	if (qual == NIL)
		return NULL;

	Assert(IsA(qual, List));

	state = makeNode(ExprState);
	state->expr = (Expr *) qual;
	state->parent = parent;
	state->ext_params = NULL;

	/* mark expression as to be used with ExecQual() */
	state->flags = EEO_FLAG_IS_QUAL;

	/* Insert setup steps as needed */
	ExecCreateExprSetupSteps(state, (Node *) qual);

	/*
	 * ExecQual() needs to return false for an expression returning NULL. That
	 * allows us to short-circuit the evaluation the first time a NULL is
	 * encountered.  As qual evaluation is a hot-path this warrants using a
	 * special opcode for qual evaluation that's simpler than BOOL_AND (which
	 * has more complex NULL handling).
	 */
	scratch.opcode = EEOP_QUAL;

	/*
	 * We can use ExprState's resvalue/resnull as target for each qual expr.
	 */
	scratch.resvalue = &state->resvalue;
	scratch.resnull = &state->resnull;

	foreach_ptr(Expr, node, qual)
	{
		/* first evaluate expression */
		ExecInitExprRec(node, state, &state->resvalue, &state->resnull);

		/* then emit EEOP_QUAL to detect if it's false (or null) */
		scratch.d.qualexpr.jumpdone = -1;
		ExprEvalPushStep(state, &scratch);
		adjust_jumps = lappend_int(adjust_jumps,
								   state->steps_len - 1);
	}

	
	

	/*
	 * At the end, we don't need to do anything more.  The last qual expr must
	 * have yielded TRUE, and since its result is stored in the desired output
	 * location, we're done.
	 */
	scratch.opcode = EEOP_CONST;
	scratch.d.constval.value = Int32GetDatum(0);
	scratch.d.constval.isnull = false;
	ExprEvalPushStep(state, &scratch);
	scratch.opcode = EEOP_DONE_RETURN;
	ExprEvalPushStep(state, &scratch);
	Assert(qual_index == 0 && "`qual_index` should be zero at the end");

	// adjust jump targets
	foreach_int(jump, adjust_jumps)
	{
		ExprEvalStep *as = &state->steps[jump];

		Assert(as->opcode == EEOP_QUAL);
		Assert(as->d.qualexpr.jumpdone == -1);
		as->d.qualexpr.jumpdone = state->steps_len;
		qual_index += 1;
		scratch.opcode = EEOP_CONST;
		scratch.d.constval.value = Int32GetDatum(qual_index);
		scratch.d.constval.isnull = false;
		ExprEvalPushStep(state, &scratch);
		scratch.opcode = EEOP_DONE_RETURN;
		ExprEvalPushStep(state, &scratch);
	}
	
	
	private = palloc(sizeof(pg_feedback_EvalFuncWithInstr));
	if (!jit_compile_expr(state)) {
		// intepret if not able to jit compile
        ExecReadyInterpretedExpr(state);
    }
	private->evaluate_with_instr = state->evalfunc;
	private->private_state = state->evalfunc_private;
	state->evalfunc = pg_feedback_evalfunc;
	state->evalfunc_private = private;
    elog(LOG, "[pg_feedback_ExecInitQual] -- instrumented");
	return state;
}

static void
show_per_qual_filtered_count(PlanState *planstate, List *ancestors, ExplainState *es)
{
	double		nfiltered = 0;
	double		nloops;
	List 		*qual_display = NIL;
	// Expr * expr;
	Instrumentation *instr;
	int qual_index = 0;
	List	   *context;
	char	   *exprstr;

	if (!es->analyze || !planstate->instrument || !planstate->plan->qual) {
		return;
	}

	instr = planstate->instrument;
	
	nloops = planstate->instrument->nloops;

	ExplainOpenGroup("Rows Removed at each Qual Step", "Rows Removed at each Qual Step", true, es);
	if (es->format == EXPLAIN_FORMAT_TEXT)
	{
		ExplainIndentText(es);
		appendStringInfoString(es->str, "Rows Removed at each Qual Step:\n");
		es->indent++;
	}
	
	foreach_ptr(Expr, node, planstate->plan->qual)
	{
		nfiltered = instr->per_qual_filtered[qual_index];
		qual_index += 1;
		qual_display = lappend(qual_display, node);
		// expr = make_ands_explicit(qual_display);

	

		/* Set up deparsing context */
		context = set_deparse_context_plan(es->deparse_cxt,
									   planstate->plan,
									   ancestors);

		/* Deparse the expression */
		exprstr = deparse_expression((Node *)node, context, es->verbose, false);
		if (nloops > 0) {
			ExplainPropertyFloat(exprstr, NULL, nfiltered / nloops, 0, es);
		} else {
			ExplainPropertyFloat(exprstr, NULL, 0.0, 0, es);
		}
	}
	
	ExplainCloseGroup("Rows Removed at each Qual Step", "Rows Removed at each Qual Step", true, es);
}

static void pg_feedback_explain_per_node(PlanState *planstate,
											List *ancestors,
											const char *relationship,
											const char *plan_name,
											ExplainState *es) {
	if (prev_explain_per_node_hook) {
		prev_explain_per_node_hook(planstate, ancestors, relationship, plan_name, es);
	} 
	if (pg_feedback_enabled) {
		show_per_qual_filtered_count(planstate, ancestors, es);
	}
}

void _PG_init(void) {
    prev_ExecInitQual_hook = ExecInitQual_hook;
    ExecInitQual_hook = pg_feedback_ExecInitQual; 
	prev_explain_per_node_hook  = explain_per_node_hook;
	explain_per_node_hook = pg_feedback_explain_per_node;

	DefineCustomBoolVariable("pg_feedback.enabled",
							 "Enable / Disable pg_feedback",
							 NULL,
							 &pg_feedback_enabled,
							 true,
							 PGC_USERSET,
							 0,
							 NULL,
							 NULL,
							 NULL);
}