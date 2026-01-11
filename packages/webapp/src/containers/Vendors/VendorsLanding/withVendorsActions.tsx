// @ts-nocheck
import { connect } from 'react-redux';
import {
  setVendorsTableState,
  resetVendorsTableState,
} from '@/store/vendors/vendors.actions';

const mapDispatchToProps = (dispatch) => ({
  setVendorsTableState: (queries) => dispatch(setVendorsTableState(queries)),
  resetVendorsTableState: () => dispatch(resetVendorsTableState()),
});

export const withVendorsActions = connect(null, mapDispatchToProps);
