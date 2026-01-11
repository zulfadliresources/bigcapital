// @ts-nocheck
import { connect } from 'react-redux';
import {
  setVendorCreditTableState,
  resetVendorCreditTableState,
} from '@/store/VendorCredit/vendorCredit.actions';

const mapDispatchToProps = (dispatch) => ({
  setVendorsCreditNoteTableState: (queries) =>
    dispatch(setVendorCreditTableState(queries)),
  resetVendorsCreditNoteTableState: () =>
    dispatch(resetVendorCreditTableState()),
});

export const withVendorsCreditNotesActions = connect(null, mapDispatchToProps);
