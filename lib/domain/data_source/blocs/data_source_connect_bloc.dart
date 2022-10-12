import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pixel_app_flutter/domain/data_source/data_source.dart';
import 'package:re_seedwork/re_seedwork.dart';

part 'data_source_connect_bloc.freezed.dart';

@immutable
class DataSourceWithAddress {
  const DataSourceWithAddress({
    required this.dataSource,
    required this.address,
  });

  final DataSource dataSource;

  final String address;

  @override
  int get hashCode => Object.hash(dataSource.hashCode, address.hashCode);

  @override
  bool operator ==(dynamic other) {
    return other is DataSourceWithAddress &&
        other.address == address &&
        other.dataSource == dataSource;
  }
}

@freezed
class DataSourceConnectEvent with _$DataSourceConnectEvent {
  const factory DataSourceConnectEvent.connect(
    DataSourceWithAddress dataSourceWithAddress,
  ) = _Connect;

  const factory DataSourceConnectEvent.tryConnectWithStorageData() =
      _TryConnectWithStorageData;
}

typedef DataSourceConnectState
    = AsyncData<Optional<DataSourceWithAddress>, Object>;

class DataSourceConnectBloc
    extends Bloc<DataSourceConnectEvent, DataSourceConnectState> {
  DataSourceConnectBloc({
    required this.dataSourceStorage,
    required this.availableDataSources,
  }) : super(const AsyncData.initial(Optional.undefined())) {
    on<_Connect>(_connect);
    on<_TryConnectWithStorageData>(_tryConnectWithStorageData);
  }

  @protected
  final DataSourceStorage dataSourceStorage;

  @protected
  final List<DataSource> availableDataSources;

  Future<void> _tryConnectWithStorageData(
    _TryConnectWithStorageData event,
    Emitter<DataSourceConnectState> emit,
  ) async {
    emit(state.inLoading());

    try {
      final values = dataSourceStorage.read();
      emit(
        await values.when(
          error: state.inFailure,
          value: (value) async {
            if (value.length != 2) {
              return state.inFailure();
            }

            final key = value.first;
            final address = value.last;

            for (final dataSource in availableDataSources) {
              if (dataSource.key == key) {
                final result = await dataSource.connect(address);

                return result.when(
                  error: state.inFailure,
                  value: (_) => AsyncData.success(
                    Optional.presented(
                      DataSourceWithAddress(
                        dataSource: dataSource,
                        address: address,
                      ),
                    ),
                  ),
                );
              }
            }

            return state.inFailure();
          },
        ),
      );
    } catch (e) {
      emit(state.inFailure());
      rethrow;
    }
  }

  Future<void> _connect(
    _Connect event,
    Emitter<DataSourceConnectState> emit,
  ) async {
    final address = event.dataSourceWithAddress.address;
    emit(AsyncData.loading(Optional.presented(event.dataSourceWithAddress)));

    try {
      final dataSource = event.dataSourceWithAddress.dataSource;
      final result = await dataSource.connect(address);

      emit(
        await result.when(
          error: (e) async => state.inFailure(),
          value: (_) async {
            await dataSourceStorage.write(
              dataSourceKey: dataSource.key,
              address: address,
            );
            return state.inSuccess();
          },
        ),
      );
    } catch (e) {
      emit(state.inFailure());
      rethrow;
    }
  }
}