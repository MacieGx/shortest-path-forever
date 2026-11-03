"""Keep screenshot UI art on its reviewed build while data tables use generated data."""

DATA_TABLES = frozenset(
    {
        "Map",
        "QuestPOIBlob",
        "QuestPOIPoint",
        "UiMapAssignment",
        "UiMapArt",
        "UiMapArtStyleLayer",
        "UiMapArtTile",
        "UiMapXMapArt",
        "WorldMapOverlay",
        "WorldMapOverlayTile",
    }
)


def make(Ui, data_build, art_build, data_tables):
    class Art(Ui):
        _DATA_TABLES = frozenset(data_tables)

        def __init__(self, *args, **kwargs):
            kwargs.setdefault("build", art_build)
            super().__init__(*args, **kwargs)
            self._data = Ui(build=data_build, scale=self.scale)
            self._atlas_cache = {}

        def atlas(self, name):
            if name not in self._atlas_cache:
                self._atlas_cache[name] = super().atlas(name)
            return self._atlas_cache[name]

        def table(self, name, key="ID"):
            if name in self._DATA_TABLES:
                return self._data.table(name, key)
            return super().table(name, key)

        def data_db2(self, name):
            return self._data.wago.db2(name)

    return Art
