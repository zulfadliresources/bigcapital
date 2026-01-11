// @ts-nocheck
import { connect } from 'react-redux';
import {
  setExpensesTableState,
  resetExpensesTableState,
} from '@/store/expenses/expenses.actions';

const mapDispatchToProps = (dispatch) => ({
  setExpensesTableState: (state) => dispatch(setExpensesTableState(state)),
  resetExpensesTableState: (state) => dispatch(resetExpensesTableState(state)),
});

export const withExpensesActions = connect(null, mapDispatchToProps);
