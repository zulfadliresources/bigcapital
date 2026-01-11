// @ts-nocheck
import { connect } from 'react-redux';
import {
  setInvoicesTableState,
  resetInvoicesTableState
} from '@/store/Invoice/invoices.actions';

const mapDipatchToProps = (dispatch) => ({
  setInvoicesTableState: (queries) => dispatch(setInvoicesTableState(queries)),
  resetInvoicesTableState: () => dispatch(resetInvoicesTableState()),
});

export const withInvoiceActions = connect(null, mapDipatchToProps);
