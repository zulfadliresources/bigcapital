// @ts-nocheck
import { connect } from 'react-redux';
import {
  setPaymentReceivesTableState,
  resetPaymentReceivesTableState,
} from '@/store/PaymentReceives/paymentReceives.actions';

const mapDispatchToProps = (dispatch) => ({
  setPaymentReceivesTableState: (state) =>
    dispatch(setPaymentReceivesTableState(state)),

  resetPaymentReceivesTableState: () =>
    dispatch(resetPaymentReceivesTableState()),
});

export const withPaymentsReceivedActions = connect(null, mapDispatchToProps);
