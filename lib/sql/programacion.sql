--Trigger para validar que en la VENTA los empleados (Vendedor y Cajero) pertenecen a la misma sucursal
CREATE OR REPLACE function emple_sucur() RETURNS TRIGGER AS $emple_sucur$
DECLARE suc1 integer;
DECLARE suc2 integer;

BEGIN
	SELECT DISTINCT s.id_sucursal INTO suc1 FROM VENTA as v1 
	LEFT JOIN EMPLEADO AS e ON new.id_empleado=e.id_empleado 
	LEFT JOIN SUCURSAL AS s ON s.id_sucursal=e.id_sucursal;

	SELECT DISTINCT s.id_sucursal INTO suc2 FROM VENTA as v2
	LEFT JOIN EMPLEADO AS e ON new.id_empleado1=e.id_empleado 
	LEFT JOIN SUCURSAL AS s ON s.id_sucursal=e.id_sucursal;

	IF 	(suc1!=suc2) THEN
		RAISE NOTICE 'Los empleados pertenecen a sucursales diferentes';
		RETURN NULL;
	END IF;
		RETURN NEW;
END;
$emple_sucur$ LANGUAGE PLPGSQL;


CREATE TRIGGER emple_sucur BEFORE INSERT OR UPDATE ON venta
FOR EACH ROW EXECUTE FUNCTION emple_sucur();


--Trigger para agregar por defecto el nombre completo en CLIENTE para razón social
CREATE OR REPLACE function razonS_Default() RETURNS TRIGGER AS $razonS_Default$
BEGIN
	IF 	(new.razon_social is NULL) THEN
		update cliente set razon_social=CONCAT(new.nombre,' ',new.apellido_paterno,' ',new.apellido_materno) WHERE rfc=new.rfc;
	END IF;
		RETURN NEW;
END;
$razonS_Default$ LANGUAGE PLPGSQL;


CREATE TRIGGER razonS_Default AFTER INSERT OR UPDATE ON cliente
FOR EACH ROW EXECUTE FUNCTION razonS_Default();


--Trigger para calcular el valor del monto por articulo en ES_VENDIDO
CREATE OR REPLACE function montoXArt() RETURNS TRIGGER AS $montoXArt$
DECLARE montoTot money;
BEGIN
	SELECT precio_venta INTO montoTot FROM articulo AS ar WHERE ar.codigo_barras=new.codigo_barras;
	IF	(TG_OP='INSERT') THEN
		update es_vendido set monto=(montoTot*new.cantidad)  WHERE codigo_barras=new.codigo_barras AND folio=new.folio;
	END IF;
	RETURN NEW;
END;
$montoXArt$ LANGUAGE PLPGSQL;


CREATE TRIGGER montoXArt AFTER INSERT OR UPDATE ON ES_VENDIDO
FOR EACH ROW EXECUTE FUNCTION montoXArt();

--Trigger para generar el formato del ID de la VENTA (MBL-XXX)
CREATE OR REPLACE FUNCTION venta_formato() RETURNS TRIGGER AS $$
DECLARE valAct smallint;
BEGIN
	valAct=CAST(new.folio AS smallint);
	IF(valAct<10) THEN
		UPDATE venta set folio=CONCAT('MBL-00',valAct) where folio=NEW.folio;
	ELSEIF(valAct<100) THEN
		UPDATE venta set folio=CONCAT('MBL-0',valAct) where folio=NEW.folio;
	ELSEIF(valAct<1000) THEN
		UPDATE venta set folio=CONCAT('MBL-',valAct) where folio=NEW.folio;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE PLPGSQL;

CREATE TRIGGER venta_formato AFTER INSERT ON venta
FOR EACH ROW EXECUTE FUNCTION venta_formato();

CREATE SEQUENCE secue_folio_venta AS smallint
	INCREMENT 1
	MINVALUE 1
	MAXVALUE 999
	START 1
	NO CYCLE
	OWNED BY VENTA.folio;

alter sequence secue_folio_venta restart [with numero];
insert into venta values(nextval('secue_folio_venta'),now(),...);