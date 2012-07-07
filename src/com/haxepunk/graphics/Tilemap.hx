package com.haxepunk.graphics;

import flash.display.BitmapData;
import flash.geom.Point;
import flash.geom.Rectangle;
import com.haxepunk.Graphic;
import com.haxepunk.HXP;
import com.haxepunk.masks.Grid;


/**
 * A canvas to which Tiles can be drawn for fast multiple tile rendering.
 */
class Tilemap extends Canvas
{
	/**
	 * If x/y positions should be used instead of columns/rows.
	 */
	public var usePositions:Bool;

	/**
	 * Constructor.
	 * @param	tileset			The source tileset image.
	 * @param	width			Width of the tilemap, in pixels.
	 * @param	height			Height of the tilemap, in pixels.
	 * @param	tileWidth		Tile width.
	 * @param	tileHeight		Tile height.
	 */
	public function new(tileset:Dynamic, width:Int, height:Int, tileWidth:Int, tileHeight:Int)
	{
		_rect = HXP.rect;

		// set some tilemap information
		_width = width - (width % tileWidth);
		_height = height - (height % tileHeight);
		_columns = Std.int(_width / tileWidth);
		_rows = Std.int(_height / tileHeight);
		if (_columns == 0 || _rows == 0) throw "Cannot create a bitmapdata of width/height = 0";
		_map = new Array<Array<Int>>();
		// initialize map
		for (y in 0..._rows)
		{
			_map[y] = new Array<Int>();
		}
		_tile = new Rectangle(0, 0, tileWidth, tileHeight);

		// create the canvas
		super(_width, _height);

		// load the tileset graphic
		if (Std.is(tileset, Class) || Std.is(tileset, String)) _set = HXP.getBitmap(tileset);
		else if (Std.is(tileset, BitmapData)) _set = tileset;
		if (_set == null) throw "Invalid tileset graphic provided.";
		_setColumns = Std.int(_set.width / tileWidth);
		_setRows = Std.int(_set.height / tileHeight);
		_setCount = _setColumns * _setRows;

#if (cpp || neko)
		_ts = HXP.spriteBatch.addSpriteSheet(tileset, tileWidth, tileHeight);
#end
	}

	/**
	 * Sets the index of the tile at the position.
	 * @param	column		Tile column.
	 * @param	row			Tile row.
	 * @param	index		Tile index.
	 */
	public function setTile(column:Int, row:Int, index:Int = 0)
	{
		if (usePositions)
		{
			column = Std.int(column / _tile.width);
			row = Std.int(row / _tile.height);
		}
		index %= _setCount;
		column %= _columns;
		row %= _rows;
		_tile.x = (index % _setColumns) * _tile.width;
		_tile.y = Std.int(index / _setColumns) * _tile.height;
		_map[row][column] = index;
		draw(Std.int(column * _tile.width), Std.int(row * _tile.height), _set, _tile);
	}

	/**
	 * Clears the tile at the position.
	 * @param	column		Tile column.
	 * @param	row			Tile row.
	 */
	public function clearTile(column:Int, row:Int)
	{
		if (usePositions)
		{
			column = Std.int(column / _tile.width);
			row = Std.int(row / _tile.height);
		}
		column %= _columns;
		row %= _rows;
		_tile.x = column * _tile.width;
		_tile.y = row * _tile.height;
#if flash
		fill(_tile, 0, 0);
#end
	}

	/**
	 * Gets the tile index at the position.
	 * @param	column		Tile column.
	 * @param	row			Tile row.
	 * @return	The tile index.
	 */
	public function getTile(column:Int, row:Int):Int
	{
		if (usePositions)
		{
			column = Std.int(column / _tile.width);
			row = Std.int(row / _tile.height);
		}
		return _map[row % _rows][column % _columns];
	}

	/**
	 * Sets a rectangular region of tiles to the index.
	 * @param	column		First tile column.
	 * @param	row			First tile row.
	 * @param	width		Width in tiles.
	 * @param	height		Height in tiles.
	 * @param	index		Tile index.
	 */
	public function setRect(column:Int, row:Int, width:Int = 1, height:Int = 1, index:Int = 0)
	{
		if (usePositions)
		{
			column = Std.int(column / _tile.width);
			row = Std.int(row / _tile.height);
			width = Std.int(width / _tile.width);
			height = Std.int(height / _tile.height);
		}
		column %= _columns;
		row %= _rows;
		var c:Int = column,
			r:Int = column + width,
			b:Int = row + height,
			u:Bool = usePositions;
		usePositions = false;
		while (row < b)
		{
			while (column < r)
			{
				setTile(column, row, index);
				column ++;
			}
			column = c;
			row ++;
		}
		usePositions = u;
	}

	/**
	 * Clears the rectangular region of tiles.
	 * @param	column		First tile column.
	 * @param	row			First tile row.
	 * @param	width		Width in tiles.
	 * @param	height		Height in tiles.
	 */
	public function clearRect(column:Int, row:Int, width:Int = 1, height:Int = 1)
	{
		if (usePositions)
		{
			column = Std.int(column / _tile.width);
			row = Std.int(row / _tile.height);
			width = Std.int(width / _tile.width);
			height = Std.int(height / _tile.height);
		}
		column %= _columns;
		row %= _rows;
		var c:Int = column,
			r:Int = column + width,
			b:Int = row + height,
			u:Bool = usePositions;
		usePositions = false;
		while (row < b)
		{
			while (column < r)
			{
				clearTile(column, row);
				column ++;
			}
			column = c;
			row ++;
		}
		usePositions = u;
	}

	public function loadFrom2DArray(array:Array<Array<Int>>):Void
	{
		for (x in 0...array.length)
		{
			for (y in 0...array[0].length)
			{
				setTile(x, y, array[x][y]);
			}
		}
	}

	/**
	* Loads the Tilemap tile index data from a string.
	* @param str			The string data, which is a set of tile values separated by the columnSep and rowSep strings.
	* @param columnSep		The string that separates each tile value on a row, default is ",".
	* @param rowSep			The string that separates each row of tiles, default is "\n".
	*/
	public function loadFromString(str:String, columnSep:String = ",", rowSep:String = "\n")
	{
		var row:Array<String> = str.split(rowSep),
			rows:Int = row.length,
			col:Array<String>, cols:Int, x:Int, y:Int;
		for (y in 0...rows)
		{
			if (row[y] == '') continue;
			col = row[y].split(columnSep);
			cols = col.length;
			for (x in 0...cols)
			{
				if (col[x] == '') continue;
				setTile(x, y, Std.parseInt(col[x]));
			}
		}
	}

	/**
	* Saves the Tilemap tile index data to a string.
	* @param columnSep		The string that separates each tile value on a row, default is ",".
	* @param rowSep			The string that separates each row of tiles, default is "\n".
	*/
	public function saveToString(columnSep:String = ",", rowSep:String = "\n"): String
	{
		var s:String = '',
			x:Int, y:Int;
		for (y in 0..._rows)
		{
			for (x in 0..._columns)
			{
				s += Std.string(getTile(x, y));
				if (x != _columns - 1) s += columnSep;
			}
			if (y != _rows - 1) s += rowSep;
		}
		return s;
	}

	/**
	 * Gets the index of a tile, based on its column and row in the tileset.
	 * @param	tilesColumn		Tileset column.
	 * @param	tilesRow		Tileset row.
	 * @return	Index of the tile.
	 */
	public function getIndex(tilesColumn:Int, tilesRow:Int):Int
	{
		return (tilesRow % _setRows) * _setColumns + (tilesColumn % _setColumns);
	}

	/**
	 * Shifts all the tiles in the tilemap.
	 * @param	columns		Horizontal shift.
	 * @param	rows		Vertical shift.
	 * @param	wrap		If tiles shifted off the canvas should wrap around to the other side.
	 */
	public function shiftTiles(columns:Int, rows:Int, wrap:Bool = false)
	{
		if (_temp == null)
		{
			_temp = new Array<Array<Int>>();
			// TODO: fill array
		}
		// if (usePositions)
		// {
		// 	columns = Std.int(columns / _tile.width);
		// 	rows = Std.int(rows / _tile.height);
		// }

		// if (!wrap) _temp.fillRect(_temp.rect, HXP.blackColor);

		// if (columns != 0)
		// {
		// 	shift(Std.int(columns * _tile.width), 0);
		// 	if (wrap) _temp.copyPixels(_map, _map.rect, HXP.zero);
		// 	_map.scroll(columns, 0);
		// 	_point.y = 0;
		// 	_point.x = columns > 0 ? columns - _columns : columns + _columns;
		// 	_map.copyPixels(_temp, _temp.rect, _point);

		// 	_rect.x = columns > 0 ? 0 : _columns + columns;
		// 	_rect.y = 0;
		// 	_rect.width = Math.abs(columns);
		// 	_rect.height = _rows;
		// 	updateRect(_rect, !wrap);
		// }

		// if (rows != 0)
		// {
		// 	shift(0, Std.int(rows * _tile.height));
		// 	if (wrap) _temp.copyPixels(_map, _map.rect, HXP.zero);
		// 	_map.scroll(0, rows);
		// 	_point.x = 0;
		// 	_point.y = rows > 0 ? rows - _rows : rows + _rows;
		// 	_map.copyPixels(_temp, _temp.rect, _point);

		// 	_rect.x = 0;
		// 	_rect.y = rows > 0 ? 0 : _rows + rows;
		// 	_rect.width = _columns;
		// 	_rect.height = Math.abs(rows);
		// 	updateRect(_rect, !wrap);
		// }
	}

	/** @private Used by shiftTiles to update a rectangle of tiles from the tilemap. */
	private function updateRect(rect:Rectangle, clear:Bool)
	{
		var x:Int = Std.int(rect.x),
			y:Int = Std.int(rect.y),
			w:Int = Std.int(x + rect.width),
			h:Int = Std.int(y + rect.height),
			u:Bool = usePositions;
		usePositions = false;
		if (clear)
		{
			while (y < h)
			{
				while (x < w) clearTile(x ++, y);
				x = Std.int(rect.x);
				y ++;
			}
		}
		else
		{
			while (y < h)
			{
				while (x < w) updateTile(x ++, y);
				x = Std.int(rect.x);
				y ++;
			}
		}
		usePositions = u;
	}

#if (cpp || neko)
	/** @private Renders the canvas. */
	public override function render(target:BitmapData, point:Point, camera:Point)
	{
		var wx:Float = 0, wy:Float = 0, tile:Int = 0,
			tw:Int = tileWidth, th:Int = tileHeight; // call properties once

		// determine start and end tiles to draw (optimization)
		var dx = camera.x - point.x,
			dy = camera.y - point.y,
			sx = Math.floor(dx / tileWidth),
			sy = Math.floor(dy / tileHeight),
			ex = Math.ceil((dx + HXP.width) / tileWidth),
			ey = Math.ceil((dy + HXP.height) / tileHeight);

		if (sx < 0) sx = 0;
		if (ex > _columns) ex = _columns;
		if (sy < 0) sy = 0;
		if (ey > _rows) ey = _rows;

		for (y in sy...ey)
		{
			wy = y * tileHeight + point.y - camera.y;

			for (x in sx...ex)
			{
				wx = x * tileWidth + point.x - camera.x;

				tile = getTile(x, y);
				if (tile == null) continue;
				HXP.spriteBatch.draw(_ts.index,
					wx, wy, _ts.offset + tile,
					1, alpha, 0, // scale, alpha, angle
					HXP.getRed(color), HXP.getGreen(color), HXP.getBlue(color));
			}
		}
	}

	public override function draw(x:Int, y:Int, source:BitmapData, rect:Rectangle = null)
	{
		// override to prevent copyPixels
	}

	private var _ts:com.haxepunk.batch.SpriteBatch.SpriteInfo;
#end

	/** @private Used by shiftTiles to update a tile from the tilemap. */
	private function updateTile(column:Int, row:Int)
	{
		setTile(column, row, _map[row % _rows][column % _columns]);
	}

	/**
	 * The tile width.
	 */
	public var tileWidth(getTileWidth, null):Int;
	private function getTileWidth():Int { return Std.int(_tile.width); }

	/**
	 * The tile height.
	 */
	public var tileHeight(getTileHeight, null):Int;
	private function getTileHeight():Int { return Std.int(_tile.height); }

	/**
	 * How many columns the tilemap has.
	 */
	public var columns(getColumns, null):Int;
	private function getColumns():Int { return _columns; }

	/**
	 * How many rows the tilemap has.
	 */
	public var rows(getRows, null):Int;
	private function getRows():Int { return _rows; }

	// Tilemap information.
	private var _map:Array<Array<Int>>;
	private var _temp:Array<Array<Int>>;
	private var _columns:Int;
	private var _rows:Int;

	// Tileset information.
	private var _set:BitmapData;
	private var _setColumns:Int;
	private var _setRows:Int;
	private var _setCount:Int;
	private var _tile:Rectangle;
}